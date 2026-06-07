//
//  PrimaryCTAButton.swift
//  Cruzero
//
//  The primary call-to-action — a fully-rounded capsule in interactive Liquid
//  Glass (Sherlock's home-screen button). Near-white glass with a faint accent
//  tint and dark ink text; on iOS 26 it morphs/squishes on press, and falls back
//  to a tinted glass surface on iOS 17–25 (see `GlassEffectCompatibility`).
//

import SwiftUI
import UIKit

struct PrimaryCTAButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// Optional override for the glass tint + glow. Defaults to the environment
    /// accent; pass a custom hue when the button needs to match a surface (e.g. the
    /// walnut-tinted CTA on the rules clipboard).
    var tint: Color? = nil
    let action: () -> Void

    @Environment(\.accentContext) private var accent

    private var glassTint: Color { tint ?? accent.primary }

    var body: some View {
        Button(action: {
            guard isEnabled, !isLoading else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(accent.primary)
                } else {
                    HStack(spacing: 8) {
                        if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                        Text(title).font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Ink.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
            // Stronger tint so the accent clearly reads, plus a soft accent glow
            // beneath so the button lifts off the flat near-white background
            // instead of melting into it.
            .compatibleGlass(tint: glassTint.opacity(0.38), cornerRadius: 28)
            .shadow(color: glassTint.opacity(0.30), radius: 16, x: 0, y: 7)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.scale)
        .disabled(!isEnabled || isLoading)
        .animation(Theme.Motion.snappy, value: isEnabled)
    }
}
