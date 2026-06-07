//
//  GlassCard.swift
//  Cruzero
//
//  A generic rounded container built on the ported `compatibleGlassStatic`
//  surface (iOS 26 Liquid Glass, gradient/stroke fallback below). The base
//  surface for sailing cards, profile sections, dashboard tiles, etc.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Theme.Radius.card
    var padding: CGFloat = 16
    /// Optional accent tint folded into the glass.
    var tint: Color = .clear
    /// `.soft` for resting cards, `.medium` for raised/active ones.
    var shadow: Theme.ShadowStyle = Theme.Shadow.soft
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .compatibleGlassStatic(tint: tint, cornerRadius: cornerRadius)
            .themeShadow(shadow)
    }
}
