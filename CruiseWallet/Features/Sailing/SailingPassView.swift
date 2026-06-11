//
//  SailingPassView.swift
//  CruiseWallet
//
//  The opened pass — a TRANSPARENT full-screen overlay, NOT a navigation push.
//  It owns no background: home and the pass share `HomeView`'s backdrop, exactly
//  like Apple Wallet, where the exiting cards are removed by motion + blur and
//  no opaque cover ever slides in.
//
//  It also does not own the card during the open/close flight. The choreography
//  is transform-driven on `HomeView`'s permanently-mounted stack cards; this
//  view's role in it:
//
//   • card slot — a fixed 236pt slot at the top of the scroll flow. While the
//     card is in flight (`showsCard == false`) it's an invisible placeholder;
//     once the open settles, `HomeView` flips `showsCard` and the REAL card
//     renders here — pixel-identical to the stack's copy, which hides in the
//     same beat, so the ownership swap is invisible and the card then scrolls
//     naturally with the content. The slot reports its global frame
//     continuously (`onCardFrame`) so the open flight can spring-correct its
//     target and the close can teleport the stack copy to wherever the card
//     has been scrolled.
//   • content + ✕ — fade in through a sharpening blur, trailing the card
//     (Wallet's signature); on close they blur back out FAST (~0.12s), before
//     the card has moved far, while `onClose` runs the reverse choreography.
//
//  The reveal is driven by plain state (`chromeLit`) with its own `withAnimation`
//  timing, NOT by `.transition`s: transitions on descendants of an inserted
//  branch composite with the branch root's animation and can't be sequenced
//  reliably.
//
//  This overlay lives inside Home's `NavigationStack` so sub-navigation (View
//  ship / full itinerary) stays `NavigationLink(value:)` resolved by Home's
//  stack, pushing over this overlay with a normal system bar.
//

import SwiftUI

struct SailingPassView: View {
    let sailing: Sailing
    let status: CruiseStatus
    /// True once the open flight has settled (`PassPhase.open`): this view owns
    /// the visible card. False during open/close flights, when `HomeView`'s
    /// stack copy is the one on screen and the slot is an empty placeholder.
    let showsCard: Bool
    let onClose: () -> Void
    /// Reports the card slot's global frame on every layout/scroll change.
    let onCardFrame: (CGRect) -> Void

    @State private var tab = 0
    /// The content + ✕ reveal track — fades through a sharpening blur.
    @State private var chromeLit = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardHeight: CGFloat = 236
    /// Wallet's content signature: it arrives through a blur that sharpens.
    private let chromeBlur: CGFloat = 6

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 18) {
                    cardSlot

                    // Content trails the card, fading in through a blur that
                    // sharpens (no slide, no theatrics — the ordering is what
                    // reads as "clean" in the Wallet capture).
                    VStack(spacing: 18) {
                        GlassSegmentedControl(items: ["Details", "Widgets"], selection: $tab)

                        Group {
                            if tab == 0 {
                                DetailsTab(sailing: sailing)
                            } else {
                                WidgetsTab(sailing: sailing)
                            }
                        }
                        .transition(.opacity)
                    }
                    .padding(.horizontal, 18)
                    .opacity(chromeLit ? 1 : 0)
                    .blur(radius: chromeLit || reduceMotion ? 0 : chromeBlur)
                }
                .padding(.top, 52)        // clears the floating top bar
                .padding(.bottom, 40)
            }

            topBar
                .opacity(chromeLit ? 1 : 0)
                .blur(radius: chromeLit || reduceMotion ? 0 : chromeBlur)
        }
        .onAppear(perform: reveal)
    }

    /// The card's home in the scroll flow. Same width and height as the stack's
    /// copy (full width minus the shared 20pt gutters), so the handoff in either
    /// direction is pixel-identical.
    private var cardSlot: some View {
        ZStack {
            if showsCard {
                WalletCard(sailing: sailing, status: status, height: cardHeight)
            } else {
                Color.clear
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            onCardFrame(frame)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: Reveal / dismiss tracks

    /// Open: content + ✕ sharpen in, trailing the card's flight (~0.12–0.37s;
    /// the card lands at ~0.15s).
    private func reveal() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) { chromeLit = true }
        } else {
            withAnimation(.easeOut(duration: 0.25).delay(0.12)) { chromeLit = true }
        }

        // DEBUG: open straight to a tab for sim screenshots.
        if ProcessInfo.processInfo.environment["CW_TAB"] == "widgets" { tab = 1 }
    }

    /// Close: content + ✕ blur out fast, before the card has moved far.
    /// (`onClose` teleport-swaps the card to the stack layer and flies it home
    /// in the same beat.)
    private func close() {
        // Mid-flight taps (✕ is technically tappable while still fading in)
        // are ignored; `HomeView` guards too, but bailing here keeps the
        // chrome from fading out under a pass that stays open.
        guard showsCard else { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0.25 : 0.12)) { chromeLit = false }
        onClose()
    }

    // MARK: Top bar (close button only — Wallet's pass has no inline title)

    private var topBar: some View {
        HStack {
            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Ink.secondary)
                    .frame(width: 34, height: 34)
                    .compatibleGlassCapsule(tint: Theme.Palette.duskIndigo.opacity(0.10))
            }
            .accessibilityLabel("Close pass")
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}
