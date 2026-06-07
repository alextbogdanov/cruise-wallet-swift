//
//  SecondaryButton.swift
//  Cruzero
//
//  The quieter companion to `PrimaryCTAButton` — a ghost/outline button used for
//  "I already have an account", "Maybe later", "Skip", etc. Tinted by the active
//  `AccentContext` but with no fill, so it recedes against the primary CTA.
//

import SwiftUI
import UIKit

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    /// `.outline` shows a hairline border; `.plain` is text-only (for skips).
    var style: Style = .outline
    let action: () -> Void

    @Environment(\.accentContext) private var accent

    enum Style { case outline, plain }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(style == .outline ? accent.primary : Theme.Ink.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background)
        }
        .buttonStyle(.scale)
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .outline:
            Capsule()
                .fill(Color.white.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(accent.primary.opacity(0.35), lineWidth: 1.5)
                )
                .themeShadow(Theme.Shadow.soft)
        case .plain:
            Color.clear
        }
    }
}
