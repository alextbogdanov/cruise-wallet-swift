//
//  OpenPassView.swift
//  CruiseWallet
//
//  The opened pass — the Apple-Wallet "lift". Shown as a full-screen overlay by
//  `HomeView` when a card is tapped. The `WalletCard` is pinned at the top and
//  carries the shared `matchedGeometryEffect`, so it flies from its stack slot up
//  to here. The pinned card is interactive: a `CardTiltController` (gyro) and an
//  in-place rotate drag combine into a single tilt that drives both the 3D
//  rotation and the foil sheen's specular streak. Beneath it a glass segmented
//  control switches the Details and Widgets tabs in a ScrollView that fades in
//  after the morph. Closing is via the glass ✕ top-right, or a swipe-down on the
//  backdrop / a thin top drag-strip — kept off the card so it never fights the
//  card's rotate, and off the ScrollView so it never fights scrolling.
//

import SwiftUI
import UIKit

struct OpenPassView: View {
    let sailing: Sailing
    let status: CruiseStatus
    let namespace: Namespace.ID
    let onClose: () -> Void

    @State private var tab = 0
    @State private var dragOffset: CGFloat = 0
    /// Drives the detail content's fade-in. Starts hidden and reveals just after
    /// the card lift settles, so the content doesn't bloom during the morph.
    @State private var revealContent = false

    /// Gyro-driven tilt (device motion) and the in-place rotate-drag tilt. These
    /// combine via `combinedTilt` to drive the card's 3D rotation + foil light.
    @StateObject private var tilt = CardTiltController()
    @State private var dragTilt: CGSize = .zero

    /// Drag distance past which release dismisses the pass.
    private let dismissThreshold: CGFloat = 120

    /// The status-bar height — a fixed top inset that does NOT change when the
    /// nav bar hides. We pin our layout to this (and `.ignoresSafeArea()`) so the
    /// matched-geometry card flies to a STABLE target instead of chasing the
    /// safe-area inset as the nav bar animates out, which would judder the morph.
    private var topInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.statusBarManager?.statusBarFrame.height ?? 20
    }

    var body: some View {
        // Single tilt source feeds both the geometry (tiltable3D) and the
        // lighting (WalletCard.light), so rotating the card moves its foil streak.
        let t = combinedTilt(gyro: tilt.tilt, drag: dragTilt)

        return ZStack(alignment: .top) {
            // OpenPassView is inserted with `.transition(.identity)` (see
            // HomeView), so this opaque backdrop is fully present from frame one
            // and occludes the home stack — the morph reads as a pure card LIFT,
            // not a cross-dissolve. It's pixel-identical to home's, so no pop.
            TextureBackground()
                .gesture(dragToDismiss)           // swipe-down on empty space dismisses

            VStack(spacing: 18) {
                // A thin invisible strip where the grabber used to be, so the
                // familiar top-pull still dismisses without a visible handle.
                Color.clear
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .gesture(dragToDismiss)

                // Matched geometry owns the card's motion (it flies from the stack
                // slot); the parent's identity transition means it doesn't fade.
                WalletCard(sailing: sailing, status: status, namespace: namespace, isOpen: true, light: t)
                    .padding(.horizontal, 20)
                    .tiltable3D(tilt: t)
                    .gesture(dragToRotate)

                ScrollView {
                    VStack(spacing: 20) {
                        GlassSegmentedControl(items: ["Details", "Widgets"], selection: $tab)

                        Group {
                            if tab == 0 {
                                DetailsTab(sailing: sailing)
                            } else {
                                WidgetsTab(sailing: sailing)
                            }
                        }
                        .transition(.opacity)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
                // Fade the content in AFTER the lift settles (driven by state, not
                // the insertion transition — which is now identity).
                .opacity(revealContent ? 1 : 0)
            }
            // Pin below the status bar with a fixed inset (see `topInset`) so the
            // morph target stays put while the nav bar animates away.
            .padding(.top, topInset + 8)
            .offset(y: dragOffset)
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Ink.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .compatibleGlass(tint: Theme.Palette.duskIndigo.opacity(0.12), cornerRadius: 22)
            }
            .buttonStyle(.scale)
            .accessibilityLabel("Close pass")
            .padding(.horizontal, 20)
            .padding(.top, topInset + 8)
        }
        .onAppear {
            tilt.start()
            // DEBUG: open straight to a tab for sim screenshots.
            if ProcessInfo.processInfo.environment["CW_TAB"] == "widgets" { tab = 1 }
            // Reveal the detail content just after the lift lands. async so the
            // state change animates (a synchronous onAppear change wouldn't).
            DispatchQueue.main.async {
                withAnimation(Theme.Motion.wallet.delay(0.06)) { revealContent = true }
            }
        }
        .onDisappear { tilt.stop() }
    }

    // MARK: Card rotate-in-place

    /// Drag anywhere on the card rotates it in place (does not dismiss). Maps the
    /// translation into a unit tilt and springs back to centre on release.
    private var dragToRotate: some Gesture {
        DragGesture()
            .onChanged { value in
                dragTilt = CGSize(
                    width: clamp(value.translation.width / 160),
                    height: clamp(value.translation.height / 160)
                )
            }
            .onEnded { _ in
                withAnimation(Theme.Motion.wallet) { dragTilt = .zero }
            }
    }

    // MARK: Drag-to-dismiss (backdrop + top strip)

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only track downward pulls; resist upward drags.
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold {
                    onClose()
                } else {
                    withAnimation(Theme.Motion.wallet) { dragOffset = 0 }
                }
            }
    }

    private func clamp(_ v: CGFloat) -> CGFloat { min(1, max(-1, v)) }
}
