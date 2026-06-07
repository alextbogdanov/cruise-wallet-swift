//
//  ScaleButtonStyle.swift
//  Cruzero
//
//  Ported from Sherlock. The 0.96 spring scale on press is applied to every
//  pressable surface in the app — it's a big part of the tactile, premium feel.
//

import SwiftUI

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ScaleButtonStyle {
    /// `.buttonStyle(.scale)` — the default pressable feel across Cruzero.
    static var scale: ScaleButtonStyle { ScaleButtonStyle() }
}
