//
//  CountdownPill.swift
//  Cruzero
//
//  A glassy capsule that counts down to (or marks) a sailing. Pre-sailing it
//  reads "23 days to go"; once aboard it flips to a live "Day 3 · onboard"
//  badge. Built on the ported `compatibleGlassCapsule`.
//

import SwiftUI

struct CountdownPill: View {
    /// Days until departure. 0 or negative ⇒ currently sailing.
    let daysUntil: Int
    var icon: String = "sailboat.fill"

    @Environment(\.accentContext) private var accent

    private var isSailing: Bool { daysUntil <= 0 }

    private var label: String {
        if isSailing {
            let day = abs(daysUntil) + 1
            return "Day \(day) · onboard"
        } else if daysUntil == 1 {
            return "Sails tomorrow"
        } else {
            return "\(daysUntil) days to go"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isSailing ? "dot.radiowaves.left.and.right" : icon)
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(accent.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .compatibleGlassCapsule(tint: accent.primary.opacity(0.15))
    }
}
