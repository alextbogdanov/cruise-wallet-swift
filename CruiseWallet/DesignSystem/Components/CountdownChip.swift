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
    /// Skip the live `.ultraThinMaterial` backdrop blur in favour of a static
    /// translucent fill. The blur is a per-frame offscreen sample; on the wallet
    /// stack ~5 chips animate at once during the open/close morph, so stack cards
    /// pass `true`. The dark scrim + stroke keep it legible and visually close.
    var lightweight: Bool = false

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
        .background(chipMaterial)
        .background(Color.black.opacity(lightweight ? 0.42 : 0.28), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
    }

    /// Live blur at rest (full instance), cheap fill when lightweight (stack cards).
    @ViewBuilder
    private var chipMaterial: some View {
        if lightweight {
            Capsule().fill(Color.white.opacity(0.12))
        } else {
            Capsule().fill(.ultraThinMaterial.opacity(0.9))
        }
    }
}
