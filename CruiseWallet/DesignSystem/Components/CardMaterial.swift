//
//  CardMaterial.swift
//  CruiseWallet
//
//  The `foilCardMaterial` modifier — a lightweight finish for card surfaces. A
//  fine edge bevel (white hairline top-leading → dark hairline bottom-trailing)
//  traces the rounded edge, then the lockup is clipped to the card silhouette.
//
//  It used to layer a live Metal sheen + 3D tilt driven by a gyro; that finish was
//  removed (too laggy — `.colorEffect` forces a per-frame offscreen pass per card)
//  in favour of this static, GPU-cheap bevel.
//
//      func foilCardMaterial(cornerRadius: CGFloat = Theme.Radius.card) -> some View
//

import SwiftUI

private struct FoilCardMaterial: ViewModifier {
    var cornerRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            // Fine edge bevel — white hairline (top-leading) → dark hairline
            // (bottom-trailing) traces the rounded edge. Plain `.normal` blend so
            // it composites without an extra offscreen pass.
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .black.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.normal)
                    .allowsHitTesting(false)
            }
            // Keep the whole lockup clipped to the card silhouette.
            .clipShape(shape)
            // The drop shadow lives solely on `WalletCard` (it varies the shadow by
            // open/resting state); a second shadow here would double it.
    }
}

extension View {
    /// Apply the static card finish: a fine edge bevel clipped to the card
    /// silhouette.
    ///
    /// - Parameter cornerRadius: Corner radius of the card silhouette.
    func foilCardMaterial(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(FoilCardMaterial(cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview("Foil card material") {
    VStack(spacing: 28) {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.Palette.duskIndigoDeep,
                             Theme.Palette.duskIndigo,
                             Theme.Palette.tealLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 320, height: 200)
            .foilCardMaterial()
            .overlay(alignment: .bottomLeading) {
                Text("CRUISE WALLET")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(18)
                    .allowsHitTesting(false)
            }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.backgroundGradient)
}
