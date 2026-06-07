//
//  WalletCard.swift
//  CruiseWallet
//
//  The Apple-Wallet pass card, reworked from `SailingCard`. Full-bleed photo, a
//  floating liquid-glass info bar (ship name + dates + line logo) and a glass
//  countdown chip. Unlike v1 it owns no navigation: tap is handled by `HomeView`,
//  and the card is the *hero* of the open-pass morph — it carries a
//  `matchedGeometryEffect` so it can fly from its stack slot to the top of the
//  open pass. `isOpen` lets the opened (overlay) instance drop the resting shadow.
//
//  The opened instance also wears a metallic-foil finish (`foilCardMaterial`)
//  whose specular streak tracks the `light` tilt vector, so the pinned pass card
//  glints as it is tilted by gyro/drag in `OpenPassView`.
//

import SwiftUI

struct WalletCard: View {
    let sailing: Sailing
    let status: CruiseStatus
    let namespace: Namespace.ID
    /// `true` for the instance pinned at the top of the open pass.
    var isOpen: Bool = false
    /// Whether to attach the shared `matchedGeometryEffect`. Exactly one rendered
    /// card per `sailing.id` carries it at a time: the stack instance drops it
    /// while that pass is open, so the id lives solely on the overlay instance and
    /// SwiftUI flies the single source from the stack slot to the top of the pass.
    var matched: Bool = true
    var height: CGFloat = 236
    /// Tilt direction (~-1...1) that drives the foil sheen's specular streak.
    /// `.zero` for the resting stack; the open pass feeds its live tilt here.
    var light: CGSize = .zero

    var body: some View {
        card.matchedGeometry(id: sailing.id, in: namespace, active: matched)
    }

    private var card: some View {
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

            CountdownChip(status: status)
                .padding(14)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { infoBar.padding(10) }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .foilCardMaterial(light: light)
        .themeShadow(isOpen ? Theme.Shadow.medium : Theme.Shadow.soft)
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
        .compatibleGlassStatic(tint: Theme.Palette.duskIndigo.opacity(0.10), cornerRadius: 16)
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

private extension View {
    /// Attach `matchedGeometryEffect` only when `active`, so a card can fully drop
    /// the id (rather than linger as a hidden non-source) and keep a single source
    /// per id across the stack→pass morph.
    @ViewBuilder
    func matchedGeometry(id: String, in ns: Namespace.ID, active: Bool) -> some View {
        if active {
            matchedGeometryEffect(id: id, in: ns)
        } else {
            self
        }
    }
}
