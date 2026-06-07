//
//  CardTiltController.swift
//  CruiseWallet
//
//  Workstream B: gyro + drag tilt controller and a 3D-tilt view modifier.
//
//  Exposes a frozen contract used by other views:
//    - CardTiltController: ObservableObject  (smoothed device tilt)
//    - View.tiltable3D(tilt:maxDegrees:)      (3D rotation + tracking shadow)
//    - combinedTilt(gyro:drag:)               (clamped sum of the two sources)
//
//  Tilt convention: a CGSize in roughly -1...1 where
//    width  = horizontal (-left   ... +right)
//    height = vertical   (-up      ... +down)
//

import SwiftUI
import CoreMotion
import UIKit

// MARK: - Clamp helper

/// Clamp a value into the unit range [-1, 1]. File-private, oddly named to
/// avoid collisions with any other `clamp` defined elsewhere in the module.
private func clampUnit(_ value: Double) -> Double {
    min(1, max(-1, value))
}

private func clampUnit(_ value: CGFloat) -> CGFloat {
    min(1, max(-1, value))
}

// MARK: - CardTiltController

/// Drives a smoothed device-tilt value from CoreMotion's attitude (roll/pitch).
///
/// On the simulator (or any device without device-motion) `tilt` simply stays
/// `.zero`, so callers fall back to drag-driven tilt. When Reduce Motion is on,
/// the gyro is never started, leaving drag as the only tilt source.
final class CardTiltController: ObservableObject {

    /// Smoothed, clamped device tilt in roughly -1...1.
    @Published var tilt: CGSize = .zero

    private let motionManager = CMMotionManager()

    /// Low-pass smoothing factor. Lower = smoother / more lag.
    private let alpha: Double = 0.15

    /// Radians-to-unit scale. Roughly 45° of roll/pitch maps to full deflection.
    private let radianScale: Double = .pi / 4

    /// Internal smoothed state (radians-mapped, pre-publish).
    private var smoothed: CGSize = .zero

    deinit {
        stop()
    }

    /// Begin device-motion updates and feed `tilt`. No-op when unavailable or
    /// when Reduce Motion is enabled.
    func start() {
        // Respect Reduce Motion: keep the gyro off so tilt stays drag-only.
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        // Simulator / devices without motion hardware: leave tilt at .zero.
        guard motionManager.isDeviceMotionAvailable else { return }

        // Avoid double-starting.
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.consume(motion)
        }
    }

    /// Stop device-motion updates.
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: Private

    private func consume(_ motion: CMDeviceMotion) {
        // roll  -> horizontal tilt (rotation about the device's long axis)
        // pitch -> vertical tilt   (nose up / down)
        let rawWidth  = clampUnit(motion.attitude.roll / radianScale)
        let rawHeight = clampUnit(motion.attitude.pitch / radianScale)

        // Low-pass smooth: smoothed = smoothed*(1-alpha) + new*alpha
        let newWidth  = smoothed.width  * (1 - alpha) + rawWidth  * alpha
        let newHeight = smoothed.height * (1 - alpha) + rawHeight * alpha
        smoothed = CGSize(width: newWidth, height: newHeight)

        let published = CGSize(width: clampUnit(newWidth),
                               height: clampUnit(newHeight))

        // Updates already arrive on .main, but stay explicit for @Published.
        if Thread.isMainThread {
            tilt = published
        } else {
            DispatchQueue.main.async { [weak self] in self?.tilt = published }
        }
    }
}

// MARK: - combinedTilt

/// Merge a gyro tilt and a drag tilt into a single clamped unit-range tilt.
func combinedTilt(gyro: CGSize, drag: CGSize) -> CGSize {
    CGSize(width: clampUnit(gyro.width + drag.width),
           height: clampUnit(gyro.height + drag.height))
}

// MARK: - tiltable3D modifier

private struct Tiltable3D: ViewModifier {
    let tilt: CGSize
    let maxDegrees: Double

    func body(content: Content) -> some View {
        content
            // Rotate about Y by horizontal tilt (left/right swivel only).
            .rotation3DEffect(
                .degrees(tilt.width * maxDegrees),
                axis: (x: 0, y: 1, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.6
            )
            // Shadow follows the horizontal tilt for a sense of depth/lift.
            .shadow(
                color: .black.opacity(0.18),
                radius: 14,
                x: tilt.width * 10,
                y: 6
            )
    }
}

extension View {
    /// Apply a 3D tilt (Y rotation only) plus a tilt-tracking shadow.
    /// - Parameters:
    ///   - tilt: unit-range tilt (width = horizontal, height = vertical).
    ///   - maxDegrees: maximum rotation at full deflection. Default 10.
    func tiltable3D(tilt: CGSize, maxDegrees: Double = 10) -> some View {
        modifier(Tiltable3D(tilt: tilt, maxDegrees: maxDegrees))
    }
}

// MARK: - Preview

#Preview("Tiltable Card") {
    @Previewable @State var drag: CGSize = .zero

    // Normalize a drag translation into roughly -1...1.
    func normalized(_ translation: CGSize) -> CGSize {
        CGSize(width: clampUnit(translation.width / 150),
               height: clampUnit(translation.height / 150))
    }

    let tilt = combinedTilt(gyro: .zero, drag: drag)

    return ZStack {
        Color.black.opacity(0.9).ignoresSafeArea()

        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.indigo, .blue, .teal],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 300, height: 190)
            .overlay(
                // Mock "light" dot tracking the same tilt so geometry + light
                // can be eyeballed together.
                Circle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .blur(radius: 6)
                    .offset(x: tilt.width * 110, y: tilt.height * 70)
                    .blendMode(.plusLighter)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .tiltable3D(tilt: tilt)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        drag = normalized(value.translation)
                    }
                    .onEnded { _ in
                        withAnimation(Theme.Motion.gentle) { drag = .zero }
                    }
            )
    }
}
