//
//  WalletStack.swift
//  CruiseWallet
//
//  The overlapping Apple-Wallet card stack, rendered inside `HomeView`'s single
//  native scroll view. Two behaviours live here:
//
//   1. Resting cascade — the soonest sailing on top, each card behind peeking its
//      bottom info bar (`peek`), z-ordered front-to-back via paint order.
//   2. Spread-on-pull — pulling the scroll past its top fans the cards apart
//      proportionally and springs them back on release. The overscroll amount is
//      measured in `HomeView` (GeometryReader + `ScrollMinYKey`, declared below)
//      and passed in as a plain value.
//
//  Open transition: each card is the SOURCE of a shared-element hero. It carries
//  `.matchedGeometryEffect(id: sailing.id, in: namespace)`, and when a card is
//  tapped `HomeView` sets it as `selected` inside a `withAnimation`. The selected
//  card is then DROPPED from this stack (the `if` below) in the same transaction
//  that `SailingPassView` inserts a card with the same id — SwiftUI bridges them
//  and the card flies from its slot to the top of the pass. Because the stack is
//  ZStack + per-index `.offset`, dropping one card leaves its slot empty and the
//  others DON'T reflow (the hero is mid-flight out of that gap anyway).
//
//  Reduce Motion: the spread factor drops to zero, so cards stay put on pull.
//
//  Empty state is owned by `HomeView`: this view assumes a non-empty `sailings`.
//

import SwiftUI

struct WalletStack: View {
    let sailings: [Sailing]
    let namespace: Namespace.ID
    /// The currently-open sailing, if any. Its card is dropped from the stack so
    /// the hero in `SailingPassView` owns the matched id and morphs cleanly.
    let selected: Sailing?
    /// Live overscroll past the top, in points (0 at rest), computed in `HomeView`.
    let overscroll: CGFloat
    let status: (Sailing) -> CruiseStatus
    let onTap: (Sailing) -> Void
    let onDelete: (Sailing) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardHeight: CGFloat = 236
    private let peek: CGFloat = 96

    /// Max extra spread per card at full pull, and how fast pull converts to spread.
    private let maxSpreadPerCard: CGFloat = 26
    private let spreadFactor: CGFloat = 0.18

    var body: some View {
        cards
            .frame(height: stackHeight, alignment: .top)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
    }

    private var cards: some View {
        // Render BACK-TO-FRONT (highest idx first) so paint order alone gives the
        // correct stacking: idx 0 (soonest sailing) is drawn last = frontmost.
        ZStack(alignment: .top) {
            ForEach(Array(sailings.enumerated()).reversed(), id: \.element.id) { idx, sailing in
                // Drop the open card so the pass's hero owns the matched id. Keyed
                // off stable `sailing.id`, never the reversed index, so the right
                // slot empties and the right card morphs.
                if selected?.id != sailing.id {
                    WalletCard(
                        sailing: sailing,
                        status: status(sailing),
                        height: cardHeight
                    )
                    .offset(y: cardOffset(idx: idx))
                    // Hero SOURCE. On the outer card (after `.offset`) so the resting
                    // on-screen rect is what the pass card flies from.
                    .matchedGeometryEffect(id: sailing.id, in: namespace)
                    // `.heroSolid`, matching the pass-side hero: both in-flight copies
                    // stay solid and pixel-identical, so the pair reads as one card —
                    // no crossfade alpha dip for the stack behind to ghost through
                    // (the "Day 3 of 7" chip bleeding into the flying card).
                    .transition(.heroSolid)
                    .onTapGesture { onTap(sailing) }
                    .contextMenu {
                        Button(role: .destructive) { onDelete(sailing) } label: {
                            Label("Remove sailing", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: Layout math

    private var effectiveSpreadEnabled: Bool { !reduceMotion }

    private func cardOffset(idx: Int) -> CGFloat {
        // Resting / spread layout: each card fans further as the pull grows.
        let pull = effectiveSpreadEnabled ? overscroll : 0
        let spread = min(pull * spreadFactor, maxSpreadPerCard) * CGFloat(idx)
        return CGFloat(idx) * peek + spread
    }

    private var stackHeight: CGFloat {
        let n = sailings.count
        return cardHeight + CGFloat(max(0, n - 1)) * peek
    }
}

// MARK: - Overscroll preference

/// Carries the content's top edge (minY) in the home scroll's coordinate space so
/// `HomeView` can derive overscroll without iOS 18's `onScrollGeometryChange`.
struct ScrollMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
