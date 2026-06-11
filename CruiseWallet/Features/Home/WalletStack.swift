//
//  WalletStack.swift
//  CruiseWallet
//
//  The overlapping Apple-Wallet card stack, rendered inside `HomeView`'s single
//  native scroll view. Three behaviours live here:
//
//   1. Resting cascade — the soonest sailing on top, each card behind peeking its
//      bottom info bar (`peek`), z-ordered front-to-back via paint order.
//   2. Spread-on-pull — pulling the scroll past its top fans the cards apart
//      proportionally and springs them back on release. The overscroll amount is
//      measured in `HomeView` (GeometryReader + `ScrollMinYKey`, declared below)
//      and passed in as a plain value.
//   3. Open/close choreography — every card stays PERMANENTLY MOUNTED and the
//      transition is pure per-card transforms (offset / scale / blur / opacity),
//      frame-matched to the real Wallet capture. No `matchedGeometryEffect`, no
//      second card instance: a buried card is revealed by its neighbours moving
//      away, never by a new card materialising, so its details can never "pop"
//      mid-press.
//
//  The transforms are driven by two independent tracks owned by `HomeView`:
//   • `flying` (hero spring) — positions. The tapped card translates from its
//     slot to the pass's card slot by `liftDelta` (computed there from measured
//     global frames). Cards ABOVE the tapped one compress into a pile tucked
//     just above the tapped card's final top edge — `peek` squeezes to
//     `pileBand`, each recedes slightly in scale — so the rising card reads as
//     pushing the pile off-screen. They sit in FRONT in paint order, exactly
//     like the resting cascade, so any mid-flight overlap reads as the cascade
//     compressing, never as z-fighting. Cards BELOW drift down a touch.
//   • `veiled` (timed ease) — blur + fade of every non-tapped card. The tapped
//     card itself is never blurred and never fades; it is the one physical card
//     the whole way.
//
//  Ownership handoff: while `phase` is `.opening`/`.closing` the stack's copy IS
//  the card; once `.open`, `SailingPassView` renders the real card in its scroll
//  flow and the stack's copy hides (opacity 0, still mounted — identity is
//  preserved so close simply reverses the transforms).
//
//  Reduce Motion: no translations, no blur — the veil collapses to plain fades
//  and the spread factor drops to zero.
//
//  Empty state is owned by `HomeView`: this view assumes a non-empty `sailings`.
//

import SwiftUI

struct WalletStack: View {
    let sailings: [Sailing]
    /// Open/close lifecycle, owned by `HomeView`. Only `.open` matters here:
    /// it hides the tapped card while the pass owns the visible one.
    let phase: PassPhase
    /// The currently-open (or in-flight) sailing, if any.
    let selected: Sailing?
    /// Position track (hero spring): true whenever the open choreography holds.
    let flying: Bool
    /// Blur/fade track (timed ease) for everything that isn't the tapped card.
    let veiled: Bool
    /// The tapped card's flight offset: pass-slot global Y minus its slot global Y.
    let liftDelta: CGFloat
    /// Live overscroll past the top, in points (0 at rest), computed in `HomeView`.
    let overscroll: CGFloat
    let status: (Sailing) -> CruiseStatus
    let onTap: (Sailing) -> Void
    let onDelete: (Sailing) -> Void
    /// Reports the cards container's global frame (its minY is slot 0's top), so
    /// `HomeView` can convert between slot positions and the pass's card slot.
    let onFrame: (CGRect) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let cardHeight: CGFloat = 236
    static let peek: CGFloat = 96

    /// Max extra spread per card at full pull, and how fast pull converts to spread.
    static let maxSpreadPerCard: CGFloat = 26
    static let spreadFactor: CGFloat = 0.18

    /// Exposed band per pile card during the open flight (Wallet compresses the
    /// resting ~96pt cascade to ~15pt as the pile tucks above the rising card).
    private let pileBand: CGFloat = 15
    /// How far the cards below the tapped one drift down as they blur out.
    private let belowDrift: CGFloat = 60

    var body: some View {
        cards
            .frame(height: stackHeight, alignment: .top)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                onFrame(frame)
            }
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
                WalletCard(
                    sailing: sailing,
                    status: status(sailing),
                    height: Self.cardHeight
                )
                .scaleEffect(scale(idx: idx))
                .offset(y: restOffset(idx: idx) + flightOffset(idx: idx))
                .blur(radius: blur(idx: idx))
                .opacity(opacity(idx: idx))
                .onTapGesture { onTap(sailing) }
                .contextMenu {
                    Button(role: .destructive) { onDelete(sailing) } label: {
                        Label("Remove sailing", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: Layout math

    private var motionEnabled: Bool { !reduceMotion }

    private var selectedIndex: Int? {
        guard let selected else { return nil }
        return sailings.firstIndex { $0.id == selected.id }
    }

    /// Resting / spread layout: each card fans further as the pull grows.
    private func restOffset(idx: Int) -> CGFloat {
        let pull = motionEnabled ? overscroll : 0
        let spread = min(pull * Self.spreadFactor, Self.maxSpreadPerCard) * CGFloat(idx)
        return CGFloat(idx) * Self.peek + spread
    }

    /// Open-choreography translation, added on top of the resting offset.
    private func flightOffset(idx: Int) -> CGFloat {
        guard let k = selectedIndex, flying, motionEnabled else { return 0 }
        if idx == k { return liftDelta }
        if idx < k {
            // Pile: tucked just above the tapped card's FINAL top edge, exposed
            // bands compressed to `pileBand`, resting order preserved (idx 0 on
            // top of the pile, nearest neighbour at its bottom).
            let targetTop = CGFloat(k) * Self.peek + liftDelta
            let pileTop = targetTop - Self.cardHeight - CGFloat(k - 1 - idx) * pileBand
            return pileTop - CGFloat(idx) * Self.peek
        }
        return belowDrift
    }

    /// Pile cards recede slightly — Wallet's "going backwards" cue.
    private func scale(idx: Int) -> CGFloat {
        guard let k = selectedIndex, flying, motionEnabled, idx < k else { return 1 }
        return max(0.9, 1 - 0.02 * CGFloat(k - idx))
    }

    /// Exiting cards blur out; the tapped card NEVER blurs. Radii stay low —
    /// these are animated on up to four cards at once and they're fading anyway.
    private func blur(idx: Int) -> CGFloat {
        guard motionEnabled, veiled, let k = selectedIndex, idx != k else { return 0 }
        return idx < k ? 10 : 12
    }

    private func opacity(idx: Int) -> Double {
        guard let k = selectedIndex else { return 1 }
        if idx == k {
            // Hidden only once the pass owns the visible card (`.open`); the
            // swap is pixel-identical so it never shows. Under Reduce Motion
            // the veil crossfades it with the pass instead.
            if phase == .open { return 0 }
            if !motionEnabled && veiled { return 0 }
            return 1
        }
        return veiled ? 0 : 1
    }

    private var stackHeight: CGFloat {
        let n = sailings.count
        return Self.cardHeight + CGFloat(max(0, n - 1)) * Self.peek
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
