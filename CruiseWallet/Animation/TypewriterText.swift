//
//  TypewriterText.swift
//  Cruzero
//
//  One signature line that types itself in, Sherlock-style, reserved for a
//  single celebratory moment (the "You're all set" finish). The full string is
//  laid out invisibly underneath so the surrounding layout never reflows as the
//  visible prefix grows — only the characters appear. Under Reduce Motion the
//  whole line renders instantly, no animation, no scheduled work.
//

import SwiftUI

struct TypewriterText: View {
    let text: String
    var font: Font = .system(size: 24, weight: .bold, design: .serif)
    var color: Color = Theme.Ink.primary
    /// Seconds between characters once typing begins.
    var perCharacter: Double = 0.045
    /// A short beat before the first character lands.
    var startDelay: Double = 0.25

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var count = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Invisible full string reserves the final frame so nothing shifts.
            Text(text).opacity(0)
            Text(String(text.prefix(count)))
        }
        .font(font)
        .foregroundStyle(color)
        .multilineTextAlignment(.leading)
        .onAppear(perform: start)
    }

    private func start() {
        guard count == 0 else { return }
        let total = text.count
        guard total > 0 else { return }

        if reduceMotion {
            count = total
            return
        }

        for i in 1...total {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + Double(i) * perCharacter) {
                count = i
            }
        }
    }
}
