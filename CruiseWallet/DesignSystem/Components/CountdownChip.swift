//
//  CountdownChip.swift
//  CruiseWallet
//
//  A small glass capsule that states a sailing's status at a glance — "24 days to
//  go", "Day 3 of 7", "30 days ago". Sits over photography (card + boarding-pass
//  hero), so it uses a dark translucent material with white text for legibility on
//  any image. Unlike the ported `CountdownPill`, it covers the "after" phase too.
//

import SwiftUI

struct CountdownChip: View {
    let status: CruiseStatus
    var prominent: Bool = false

    private var symbol: String {
        switch status {
        case .before: return "calendar"
        case .during: return "dot.radiowaves.left.and.right"
        case .after:  return "checkmark.seal.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 13 : 12, weight: .bold))
            Text(status.countdownText)
                .font(.system(size: prominent ? 15 : 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, prominent ? 14 : 11)
        .padding(.vertical, prominent ? 8 : 6)
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        .background(Color.black.opacity(0.28), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
    }
}
