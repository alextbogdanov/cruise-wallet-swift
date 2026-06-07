//
//  WalletStack.swift
//  CruiseWallet
//
//  The overlapping Apple-Wallet card stack, extracted from `HomeView` so it can
//  own its own choreography. Three behaviours live here:
//
//   1. Resting cascade — the soonest sailing on top, each card behind peeking its
//      bottom info bar (`peek`), z-ordered front-to-back.
//   2. Spread-on-pull — pulling the scroll past its top (overscroll) fans the
//      cards apart proportionally and springs them back on release. Overscroll is
//      measured with a GeometryReader + PreferenceKey (iOS 17 has no
//      `onScrollGeometryChange`): the content's minY in a named coordinate space
//      is published, and the resting minY (captured once) is subtracted.
//   3. Open choreography — when a card is tapped (`openSailing` set), the tapped
//      card is the matched-geometry hero (we just hide it, opacity 0). Cards
//      *above* it collapse into a tight stack pinned near the top; cards *below*
//      slide down off-screen and fade. A small per-card stagger ripples outward
//      from the hero. Everything is driven by the `openSailing` binding, so close
//      reverses it symmetrically.
//
//  Reduce Motion: the spread factor and the stagger both drop to zero, so cards
//  move together / stay put rather than fanning or rippling.
//
//  Empty state is owned by `HomeView`: when `sailings.isEmpty` this view renders
//  nothing and `HomeView` shows its empty placeholder instead.
//

import SwiftUI

struct WalletStack: View {
    let sailings: [Sailing]
    let namespace: Namespace.ID
    @Binding var openSailing: Sailing?
    let status: (Sailing) -> CruiseStatus
    let onTap: (Sailing) -> Void
    let onDelete: (Sailing) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Live overscroll past the top, in points (0 at rest, grows when pulled down).
    @State private var overscroll: CGFloat = 0
    /// Resting content minY, captured on first measurement.
    @State private var restMinY: CGFloat?

    private let cardHeight: CGFloat = 236
    private let peek: CGFloat = 96

    /// Tight stack the *above* cards collapse into when a pass opens.
    private let openTopPeek: CGFloat = 8
    /// How far *below* cards slide down off-screen when a pass opens.
    private let openBelowDrop: CGFloat = 900

    /// Max extra spread per card at full pull, and how fast pull converts to spread.
    private let maxSpreadPerCard: CGFloat = 26
    private let spreadFactor: CGFloat = 0.18

    private let scrollSpace = "walletStackScroll"

    var body: some View {
        if sailings.isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // Invisible probe that reports the content's top in our space.
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ScrollMinYKey.self,
                        value: geo.frame(in: .named(scrollSpace)).minY
                    )
                }
                .frame(height: 0)

                cards
            }
            .frame(height: stackHeight, alignment: .top)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            // The native large title reserves its own bar space; just a little
            // breathing room beneath it.
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .coordinateSpace(name: scrollSpace)
        .onPreferenceChange(ScrollMinYKey.self) { minY in
            // First reading establishes the rest position.
            if restMinY == nil { restMinY = minY }
            let rest = restMinY ?? minY
            let pulled = max(0, minY - rest)
            // Drive the spread directly off the live offset so release springs it
            // back to zero with the scroll's own rubber-band.
            overscroll = effectiveSpreadEnabled ? pulled : 0
        }
    }

    private var cards: some View {
        ForEach(Array(sailings.enumerated()), id: \.element.id) { idx, sailing in
            WalletCard(
                sailing: sailing,
                status: status(sailing),
                namespace: namespace,
                matched: openSailing?.id != sailing.id,
                height: cardHeight
            )
            .opacity(cardOpacity(idx: idx, sailing: sailing))
            .offset(y: cardOffset(idx: idx, sailing: sailing))
            .zIndex(Double(-idx))
            .onTapGesture { onTap(sailing) }
            .contextMenu {
                Button(role: .destructive) { onDelete(sailing) } label: {
                    Label("Remove sailing", systemImage: "trash")
                }
            }
            .animation(openAnimation(idx: idx), value: openSailing?.id)
        }
    }

    // MARK: Layout math

    private var effectiveSpreadEnabled: Bool {
        !reduceMotion && openSailing == nil
    }

    /// Index of the tapped/open card, if any.
    private var heroIndex: Int? {
        guard let open = openSailing else { return nil }
        return sailings.firstIndex(where: { $0.id == open.id })
    }

    private func cardOpacity(idx: Int, sailing: Sailing) -> Double {
        // The hero is handled by matchedGeometry — hide the stack instance.
        if openSailing?.id == sailing.id { return 0 }
        // Below-hero cards fade out as they drop away.
        if let hero = heroIndex, idx > hero { return 0 }
        return 1
    }

    private func cardOffset(idx: Int, sailing: Sailing) -> CGFloat {
        if let hero = heroIndex {
            if idx < hero {
                // Above the hero: collapse into a tight stack near the top.
                return CGFloat(idx) * openTopPeek
            } else if idx > hero {
                // Below the hero: slide down off-screen.
                return openBelowDrop
            }
            // The hero itself keeps its resting slot (it's hidden anyway).
            return CGFloat(idx) * peek
        }
        // Resting / spread layout: each card fans further as the pull grows.
        let spread = min(overscroll * spreadFactor, maxSpreadPerCard) * CGFloat(idx)
        return CGFloat(idx) * peek + spread
    }

    private func openAnimation(idx: Int) -> Animation {
        guard !reduceMotion else { return Theme.Motion.wallet }
        let distance = heroIndex.map { abs(idx - $0) } ?? abs(idx)
        return Theme.Motion.wallet.delay(Double(distance) * 0.03)
    }

    private var stackHeight: CGFloat {
        let n = sailings.count
        return cardHeight + CGFloat(max(0, n - 1)) * peek
    }
}

// MARK: - Overscroll preference

/// Carries the content's top edge (minY) in the scroll's coordinate space so the
/// stack can derive overscroll without iOS 18's `onScrollGeometryChange`.
private struct ScrollMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
