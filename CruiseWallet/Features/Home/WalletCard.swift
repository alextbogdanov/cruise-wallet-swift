//
//  WalletCard.swift
//  CruiseWallet
//
//  The Apple-Wallet pass card. Full-bleed photo, a floating liquid-glass info bar
//  (ship name + dates + line logo) and a glass countdown chip. It owns no
//  navigation: tap is handled by `WalletStack`/`HomeView`. The card is also the
//  *source* of the native zoom transition into `SailingPassView` — but that hook
//  (`.matchedTransitionSource`) lives on the stack's card view, not here, so this
//  type is a plain, presentation-only card used identically in the stack and at
//  the top of the open pass.
//
//  The finish is flat and fast: photo + glass info bar + countdown chip + a static
//  edge bevel (`foilCardMaterial`) + a soft drop shadow. No Metal sheen, gyro, or tilt.
//

import SwiftUI

struct WalletCard: View {
    let sailing: Sailing
    let status: CruiseStatus
    var height: CGFloat = 236

    var body: some View {
        ZStack(alignment: .topLeading) {
            AssetImage(name: sailing.backgroundAsset, label: "\(sailing.embarkPort) · \(sailing.shipName)")
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipped()

            // Top scrim so the chip reads on bright photos.
            LinearGradient(
                colors: [.black.opacity(0.25), .clear],
                startPoint: .top, endPoint: .center
            )

            CountdownChip(status: status, lightweight: true)
                .padding(14)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { infoBar.padding(10) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .foilCardMaterial()
        .themeShadow(Theme.Shadow.soft)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var infoBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(sailing.shipName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.Ink.primary)
                    .lineLimit(1)
                Text("\(Formatters.medium(sailing.departureDate)) · \(sailing.length) nights")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            logoTile
        }
        .padding(12)
        .compatibleGlassStatic(tint: Theme.Palette.duskIndigo.opacity(0.10), cornerRadius: 16, lightweight: true)
    }

    private var logoTile: some View {
        AssetImage(name: sailing.cruiseLineLogoAsset ?? "", label: nil)
            .frame(width: 38, height: 38)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.Ink.hairline, lineWidth: 1)
            )
    }
}
