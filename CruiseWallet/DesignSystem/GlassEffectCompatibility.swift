//
//  GlassEffectCompatibility.swift
//  Cruzero
//
//  Ported verbatim from Sherlock. Provides iOS 17+ compatibility for the glass
//  surfaces that define the premium feel.
//  On iOS 26+: Uses native Liquid Glass (.glassEffect)
//  On iOS 17-25: Uses a gradient + stroke + shadow fallback for glass-like depth
//

import SwiftUI

// MARK: - Glass Effect for RoundedRectangle

extension View {
    /// Glass effect with tint for RoundedRectangle
    @ViewBuilder
    func compatibleGlass(
        tint: Color = .clear,
        cornerRadius: CGFloat = 20,
        style: RoundedCornerStyle = .continuous
    ) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                .regular.interactive().tint(tint),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: style)
            )
        } else {
            self.background(
                ZStack {
                    // Solid white base for visibility
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .fill(Color.white)
                    // Tint overlay - boost opacity significantly for visibility
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .fill(tint.opacity(4.0)) // Boost to counteract the 0.15 passed in
                    // Top highlight for glass-like depth
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.7), .white.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    // Border for crisp edges
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: style))
        }
    }

    /// Non-interactive glass effect (for display elements, not buttons).
    ///
    /// `lightweight` forces the cheap gradient-fill fallback even on iOS 26,
    /// skipping native Liquid Glass (`.glassEffect`). Liquid Glass is a live
    /// backdrop blur — fine for one static surface, but murderous when many
    /// instances animate at once (the wallet stack composites one per card every
    /// frame during the open/close morph). Over a photographic card the fallback
    /// reads near-identically, so stack cards pass `true` and only the single
    /// pinned open card keeps real glass.
    @ViewBuilder
    func compatibleGlassStatic(
        tint: Color = .clear,
        cornerRadius: CGFloat = 20,
        style: RoundedCornerStyle = .continuous,
        lightweight: Bool = false
    ) -> some View {
        if #available(iOS 26, *), !lightweight {
            self.glassEffect(
                .regular.tint(tint),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: style)
            )
        } else {
            self.background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .fill(tint.opacity(0.15))
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .fill(.white.opacity(0.3))
                    RoundedRectangle(cornerRadius: cornerRadius, style: style)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: style))
        }
    }
}

// MARK: - Glass Effect for Capsule

extension View {
    /// Glass effect with tint for Capsule shape
    @ViewBuilder
    func compatibleGlassCapsule(tint: Color = .clear) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                .regular.interactive().tint(tint),
                in: Capsule()
            )
        } else {
            self.background(
                ZStack {
                    // Clean white base
                    Capsule()
                        .fill(Color.white)
                    // Subtle gradient for depth
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    // Border for definition
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .clipShape(Capsule())
        }
    }
}
