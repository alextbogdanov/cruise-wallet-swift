//
//  StatTile.swift
//  CruiseWallet
//
//  A small glass tile: SF Symbol + uppercase label + value (+ optional sub). The
//  premium replacement for the RN pass's flat 2×2 info grid cells. Used on the
//  boarding pass, the Voyage tab, and the Ship spec grid.
//

import SwiftUI

struct StatTile: View {
    let symbol: String
    let label: String
    let value: String
    var sub: String? = nil

    var body: some View {
        GlassCard(cornerRadius: Theme.Radius.tile, padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Palette.duskIndigo)
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.Ink.tertiary)
                }
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let sub {
                    Text(sub)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Ink.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
