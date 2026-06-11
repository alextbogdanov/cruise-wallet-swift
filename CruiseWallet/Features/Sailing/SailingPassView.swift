//
//  SailingPassView.swift
//  CruiseWallet
//
//  The opened pass — a full-screen HERO overlay, NOT a navigation push. Apple
//  Wallet's open is a TRUE shared-element transition: only the card is matched
//  (it flies + resizes from its stack slot to the top of this screen via
//  `matchedGeometryEffect`), while everything else fades on its own track.
//
//  Layers, each on its own STAGGERED timeline (pure fades, no slides — what reads
//  as "clean" in the Wallet capture is the ordering, not the curves):
//   • background  — fades in FAST and leads on open (it is what visually removes
//                   the home screen, so the incoming content never double-exposes
//                   over the stack); on close it TRAILS the card so home is only
//                   revealed as the card flies home.
//   • hero card   — `matchedGeometryEffect(id: sailing.id)`, MORPHS, stays solid
//                   (`.heroSolid`) so the in-flight pair never dips below full
//                   opacity and nothing ghosts through from behind.
//   • content + ✕ — trail the background slightly on open; drop out FIRST on
//                   close, before the card moves far.
//
//  The stagger is driven by plain state (`backgroundLit`/`chromeLit`) with
//  per-layer `withAnimation` timings, NOT by child `.transition`s: transitions on
//  descendants of an inserted/removed branch composite with the branch root's own
//  fade and can't be sequenced reliably. The root instead carries `.heroSolid`
//  (a near-no-op modifier transition) so the branch stays mounted — un-faded —
//  for the whole transaction while the card flies and the state fades play out.
//
//  This overlay MUST live inside Home's `NavigationStack`: `matchedGeometryEffect`
//  cannot bridge across that stack's UIKit hosting boundary (a sibling overlay's
//  card teleports instead of flying — verified by frame capture). Sub-navigation
//  (View ship / full itinerary) therefore stays `NavigationLink(value:)` resolved
//  by Home's stack, pushing over this overlay with a normal system bar.
//

import SwiftUI

/// Near-no-op fade (1 → 0.99) that keeps a view mounted — and visually solid —
/// for the whole insertion/removal transaction. Unlike `.identity`, which has
/// nothing to animate and so short-circuits (the view pops, and any
/// `matchedGeometryEffect` flight riding the removal is killed), this gives the
/// transition a real animatable change with an imperceptible visual delta.
extension AnyTransition {
    static let heroSolid = AnyTransition.modifier(
        active: HeroSolidModifier(opacity: 0.99),
        identity: HeroSolidModifier(opacity: 1)
    )
}

struct HeroSolidModifier: ViewModifier {
    var opacity: Double
    func body(content: Content) -> some View { content.opacity(opacity) }
}

struct SailingPassView: View {
    let sailing: Sailing
    let status: CruiseStatus
    /// Shared hero namespace owned by `HomeView` (also used by the stack card).
    let namespace: Namespace.ID
    let onClose: () -> Void

    @State private var tab = 0
    /// Track 1 — the opaque texture that covers/reveals home.
    @State private var backgroundLit = false
    /// Track 2 — below-card content and the ✕ button.
    @State private var chromeLit = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardHeight: CGFloat = 236

    var body: some View {
        ZStack(alignment: .top) {
            // Track 1 — background. Leads in, trails out; what "removes" home.
            TextureBackground()
                .ignoresSafeArea()
                .opacity(backgroundLit ? 1 : 0)

            ScrollView {
                VStack(spacing: 18) {
                    // The HERO. Same WalletCard, same size as the stack slot, so
                    // the morph is a clean lift (translate) rather than a stretch.
                    // Solid through the flight; it morphs, it never fades.
                    WalletCard(sailing: sailing, status: status, height: cardHeight)
                        .matchedGeometryEffect(id: sailing.id, in: namespace)
                        .frame(height: cardHeight)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .transition(.heroSolid)

                    // Track 2 — separate content, a plain fade in place that
                    // trails the background (no slide, no theatrics).
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
                }
                .padding(.top, 52)        // clears the floating top bar
                .padding(.bottom, 40)
            }

            topBar
                .opacity(chromeLit ? 1 : 0)
        }
        // Keep the whole branch mounted and UN-faded for the full open/close
        // transaction; the per-layer state fades above are the only opacity moves.
        .transition(.heroSolid)
        .onAppear(perform: reveal)
    }

    // MARK: Staggered tracks

    /// Open: background leads fast; content + ✕ trail slightly.
    private func reveal() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                backgroundLit = true
                chromeLit = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.18)) { backgroundLit = true }
            withAnimation(.easeOut(duration: 0.30).delay(0.08)) { chromeLit = true }
        }

        // DEBUG: open straight to a tab for sim screenshots.
        if ProcessInfo.processInfo.environment["CW_TAB"] == "widgets" { tab = 1 }
    }

    /// Close: content + ✕ drop out first; background trails the card home.
    /// (`onClose` flies the card via the hero spring in the same beat.)
    private func close() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                backgroundLit = false
                chromeLit = false
            }
        } else {
            withAnimation(.easeOut(duration: 0.12)) { chromeLit = false }
            withAnimation(.easeOut(duration: 0.28).delay(0.10)) { backgroundLit = false }
        }
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
