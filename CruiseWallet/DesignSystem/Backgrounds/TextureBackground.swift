//
//  TextureBackground.swift
//  Cruzero
//
//  The app's base surface: a flat, clean near-white gradient (Sherlock-exact).
//  No grain — white stays white. Kept as a named view so every screen shares
//  one backdrop and a future texture pass would only touch this file.
//

import SwiftUI

struct TextureBackground: View {
    var body: some View {
        Theme.backgroundGradient
            .ignoresSafeArea()
    }
}

#Preview {
    TextureBackground()
}
