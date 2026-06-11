//
//  HomeView.swift
//  CruiseWallet
//
//  The wallet. An overlapping Apple-Wallet card stack (`WalletStack`) inside a
//  single native scroll view under a large "Cruise Wallet" title. Tapping a card
//  runs the Wallet open choreography as PURE TRANSFORMS on permanently-mounted
//  cards — no `matchedGeometryEffect`, no second card instance, no covering
//  background. Home and the pass share this screen's `TextureBackground`; the
//  exiting cards and title are *removed by motion + blur*, exactly like the
//  reference capture:
//
//   • tapped card — translates from its slot to the pass's card slot, full
//     size, solid, never blurred (hero spring: at the slot ~0.15s, settled
//     ~0.27s). It is the same physical view the whole way, so a buried card's
//     details cannot change as it's revealed.
//   • cards above — compress into a receding pile tucked just above the rising
//     card's final top edge, then blur + fade ("the card pushes the pile off").
//   • cards below + title/header — heavy blur + fade, slight downward drift.
//   • pass content + ✕ — fade in through a sharpening blur, trailing the card.
//
//  Sequencing lives in `PassPhase` + two animation tracks: `cardFlying` rides
//  the hero spring (positions) and `veiled` rides short eased fades
//  (blur/opacity). `withAnimation(_:completionCriteria:)` lands the ownership
//  handoff: during flight the card belongs to the stack layer; once `.open` the
//  pass renders the real card inside its own scroll flow (so it scrolls
//  naturally) and the stack copy hides — the two are pixel-identical, so the
//  swap is invisible. On close the stack copy is teleported (un-animated) to
//  the pass card's CURRENT measured frame — the user may have scrolled — and
//  the reverse choreography flies it home.
//
//  Geometry: the stack reports its cards container's global frame (slot 0's
//  top); the pass reports its card slot's global frame continuously. The flight
//  delta starts from a derived constant (safe-area top + the pass's fixed
//  paddings) and is spring-corrected the moment the pass's first measurement
//  lands, so scroll position and future layout tweaks can't desync it. Home's
//  scroll gets `.scrollClipDisabled()` so the pile can exit its bounds, and is
//  disabled while a pass is up.
//
//  Chrome: the system navigation bar is PERMANENTLY hidden at this root, and the
//  large title + collapsing inline header are recreated as plain content (the
//  title row scrolls with the cards; `header` pins an inline bar that fades in
//  past the collapse threshold, driven by the same scroll probe as the stack's
//  pull-to-fan). With no system bar EVER, the safe area is constant, so nothing
//  re-layouts during open/close — only transforms and opacity move.
//
//  The pass overlay must stay INSIDE this `NavigationStack` so sub-pushes (View
//  ship, full itinerary) ride it via `NavigationLink(value:)`; pushed screens
//  show normal bars over the hidden root.
//

import SwiftUI

/// Lifecycle of the open pass. Sequences the card-ownership handoffs and guards
/// re-entrancy (tap during close, ✕ during open).
enum PassPhase: Equatable {
    /// Wallet at rest; no pass mounted.
    case closed
    /// Card in flight to the pass slot — the STACK owns the visible card.
    case opening
    /// Pass settled — the PASS owns the visible card (it scrolls with content).
    case open
    /// Card in flight back to its slot — the STACK owns the visible card.
    case closing
}

struct HomeView: View {
    @EnvironmentObject private var store: MockStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var path = NavigationPath()
    /// The open pass, if any. Mounted for the whole open→close lifecycle.
    @State private var selected: Sailing?
    @State private var phase: PassPhase = .closed
    /// Position track — rides the hero spring. Stays true while the pass is up
    /// (the exited cards hold their pile/drift targets, invisibly).
    @State private var cardFlying = false
    /// Blur/fade track — rides short eased fades on its own timing.
    @State private var veiled = false
    /// Tapped card's flight translation: pass-slot global Y − its slot global Y.
    @State private var liftDelta: CGFloat = 0
    /// Cards container's global frame, reported by `WalletStack` (minY = slot 0).
    @State private var stackFrame: CGRect = .zero
    /// The pass card slot's global frame, reported continuously while mounted
    /// (tracks the pass's own scrolling for the close teleport).
    @State private var passCardFrame: CGRect = .zero
    /// Top safe-area inset, for deriving the pass card's resting global Y before
    /// the pass has been laid out.
    @State private var safeAreaTop: CGFloat = 0
    @State private var pendingDelete: Sailing?
    @State private var showDebug = false

    /// Frame-matched to the Wallet capture: the card reaches its slot in ~0.15s
    /// and is settled by ~0.27s with a barely-there overshoot.
    private let heroSpring: Animation = .spring(response: 0.42, dampingFraction: 0.84)
    /// Exiting cards + title blur/fade in the flight's last stretch (~0.05–0.23s).
    private let veilIn: Animation = .easeOut(duration: 0.18).delay(0.05)
    /// …and sharpen back while the card flies home, trailing slightly.
    private let veilOut: Animation = .easeOut(duration: 0.22).delay(0.05)

    /// Signed scroll offset from rest (negative when scrolled up, positive on
    /// overscroll pull). Drives both the stack's fan-out and the header collapse.
    @State private var scrollOffset: CGFloat = 0
    /// Resting content minY, captured on first measurement.
    @State private var restMinY: CGFloat?

    private let scrollSpace = "home"
    /// Pinned inline-header row height (the recreated "collapsed" bar).
    private let headerHeight: CGFloat = 44

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                home

                // The pass overlay: transparent over home (shared backdrop —
                // exit-motion + blur do the covering, never an opaque slide-in).
                if let selected {
                    SailingPassView(
                        sailing: selected,
                        status: store.status(for: selected),
                        showsCard: phase == .open,
                        onClose: close,
                        onCardFrame: passCardMoved
                    )
                    .zIndex(2)
                    // Inert during the transform-driven open/close (those moves
                    // are never inside an animated transaction); under Reduce
                    // Motion the whole overlay crossfades instead.
                    .transition(.opacity)
                }
            }
            // No system bar at this root, ever — the title/header above are ours.
            // Pushed screens (ship / itinerary) still get normal system bars.
            .toolbar(.hidden, for: .navigationBar)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.safeAreaInsets.top
            } action: { inset in
                safeAreaTop = inset
            }
            .navigationDestination(for: ShipRoute.self) { route in
                ShipView(sailing: route.sailing)
            }
            .navigationDestination(for: ItineraryRoute.self) { route in
                FullItineraryView(sailing: route.sailing)
            }
            .confirmationDialog(
                "Remove this sailing?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                presenting: pendingDelete
            ) { sailing in
                Button("Remove", role: .destructive) { store.delete(sailing) }
                Button("Cancel", role: .cancel) {}
            } message: { sailing in
                Text(sailing.shipName)
            }
            .sheet(isPresented: $showDebug) { DebugMenu() }
            .onAppear(perform: applyLaunchHooks)
        }
    }

    // MARK: Home (custom large title + stack)

    private var home: some View {
        ScrollView {
            // Invisible probe that reports the content's top in our space, so
            // scrolling can collapse the header and pulling can fan the stack.
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollMinYKey.self,
                    value: geo.frame(in: .named(scrollSpace)).minY
                )
            }
            .frame(height: 0)

            largeTitleRow
                .blur(radius: veiled && !reduceMotion ? 8 : 0)
                .opacity(veiled ? 0 : 1)

            if store.sailings.isEmpty {
                emptyState
            } else {
                WalletStack(
                    sailings: store.sortedSailings,
                    phase: phase,
                    selected: selected,
                    flying: cardFlying,
                    veiled: veiled,
                    liftDelta: liftDelta,
                    overscroll: max(0, scrollOffset),
                    status: { store.status(for: $0) },
                    onTap: open,
                    onDelete: { pendingDelete = $0 },
                    onFrame: { stackFrame = $0 }
                )
            }
        }
        .coordinateSpace(name: scrollSpace)
        // The pile flies past the content's top edge during open — never clip it.
        .scrollClipDisabled()
        .scrollDisabled(phase != .closed)
        // Opacity-0 views still hit-test in SwiftUI; while a pass is up, home
        // (veiled cards, debug button) must be fully inert.
        .allowsHitTesting(phase == .closed)
        .onPreferenceChange(ScrollMinYKey.self) { minY in
            // First reading establishes the rest position; the signed offset
            // tracks both the upward scroll (header collapse) and the live pull
            // (stack fan), so release springs back with the scroll's rubber-band.
            if restMinY == nil { restMinY = minY }
            let rest = restMinY ?? minY
            scrollOffset = minY - rest
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .blur(radius: veiled && !reduceMotion ? 8 : 0)
                .opacity(veiled ? 0 : 1)
        }
        .background(TextureBackground().ignoresSafeArea())
    }

    /// The recreated large title — ordinary scroll content, so it slides under
    /// the pinned header naturally (native large-title behaviour, minus the bar).
    private var largeTitleRow: some View {
        Text("Cruise Wallet")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(Theme.Ink.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }

    /// Pinned inline header: hosts the debug button at bar level, and fades in a
    /// centred inline title + material once the large title scrolls under it.
    private var header: some View {
        HStack {
            Spacer()
            Button {
                showDebug = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Ink.primary)
                    .frame(width: 34, height: 34)
                    .compatibleGlassCapsule(tint: Theme.Palette.duskIndigo.opacity(0.10))
            }
            .accessibilityLabel("Debug menu")
        }
        .padding(.horizontal, 20)
        .frame(height: headerHeight)
        .overlay {
            Text("Cruise Wallet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Ink.primary)
                .opacity(collapseProgress)
        }
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Divider().background(Theme.Ink.hairline)
                }
                .ignoresSafeArea(edges: .top)
                .opacity(collapseProgress)
        }
    }

    /// 0 while the large title is visible, ramping to 1 as it slides under the
    /// header (collapse threshold ≈ the title row's height).
    private var collapseProgress: CGFloat {
        let collapsed = -scrollOffset - 44
        return min(max(collapsed / 14, 0), 1)
    }

    // MARK: Geometry (slot ↔ pass-slot conversions, all in global space)

    /// Where slot `idx`'s card top sits right now, including any live spread.
    private func slotGlobalY(_ idx: Int) -> CGFloat {
        let pull = reduceMotion ? 0 : max(0, scrollOffset)
        let spread = min(pull * WalletStack.spreadFactor, WalletStack.maxSpreadPerCard) * CGFloat(idx)
        return stackFrame.minY + CGFloat(idx) * WalletStack.peek + spread
    }

    /// The pass card slot's resting global Y, derived from its fixed layout
    /// (scroll content top + 52 + 4) before the pass has reported a measurement.
    private var passCardRestingY: CGFloat { safeAreaTop + 52 + 4 }

    private func index(of sailing: Sailing) -> Int? {
        store.sortedSailings.firstIndex { $0.id == sailing.id }
    }

    /// Continuous measurement from the pass's card slot. During the open flight
    /// it spring-corrects the derived target (a no-op when they already agree);
    /// afterwards it tracks the pass's scrolling so close can teleport exactly.
    private func passCardMoved(_ frame: CGRect) {
        passCardFrame = frame
        guard phase == .opening, let sailing = selected, let k = index(of: sailing) else { return }
        let desired = frame.minY - slotGlobalY(k)
        guard abs(desired - liftDelta) > 0.5 else { return }
        withAnimation(heroSpring) { liftDelta = desired }
    }

    // MARK: Open / close (transform-driven choreography)

    private func open(_ sailing: Sailing) {
        guard phase == .closed, let k = index(of: sailing) else { return }

        if reduceMotion {
            // No translations, no blur: a plain crossfade between home and pass.
            withAnimation(.easeOut(duration: 0.25)) {
                selected = sailing
                phase = .open
                veiled = true
            }
            return
        }

        // Mount the pass un-animated (its content is dark until its own reveal),
        // then run the two tracks: spring for positions, ease for the veil.
        selected = sailing
        passCardFrame = .zero
        liftDelta = passCardRestingY - slotGlobalY(k)
        phase = .opening
        withAnimation(heroSpring, completionCriteria: .logicallyComplete) {
            cardFlying = true
        } completion: {
            // Handoff: the pass renders the real card, the stack copy hides —
            // pixel-identical and static, so the swap is invisible.
            guard phase == .opening else { return }
            phase = .open
        }
        withAnimation(veilIn) { veiled = true }
    }

    private func close() {
        guard phase == .open, let sailing = selected, let k = index(of: sailing) else { return }

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) {
                selected = nil
                phase = .closed
                veiled = false
            }
            return
        }

        // Teleport (un-animated) the stack's copy to wherever the pass card
        // actually is — the user may have scrolled the pass — and take the
        // visible card back in the same beat, then fly everything home.
        if passCardFrame != .zero {
            liftDelta = passCardFrame.minY - slotGlobalY(k)
        }
        phase = .closing
        withAnimation(heroSpring, completionCriteria: .logicallyComplete) {
            cardFlying = false
        } completion: {
            guard phase == .closing else { return }
            phase = .closed
            selected = nil
        }
        withAnimation(veilOut) { veiled = false }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sailboat")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.Palette.duskIndigo)
                .frame(width: 88, height: 88)
                .background(Theme.Palette.duskIndigo.opacity(0.10), in: Circle())
            Text("No sailings yet")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.Ink.primary)
            Text("Track your upcoming cruises and count down the days.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.Ink.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    // MARK: DEBUG launch hooks

    /// `CW_OPEN_SAILING=<id>` opens a pass on launch by jumping straight to the
    /// settled `.open` state (no animation — already-open for screenshots);
    /// `CW_PUSH=ship|itinerary` then pushes a sub-screen over it. `CW_TAB` is
    /// read by `SailingPassView` itself.
    private func applyLaunchHooks() {
        guard let id = store.openSailingOnLaunch,
              let sailing = store.sortedSailings.first(where: { $0.id == id }) else { return }
        selected = sailing
        phase = .open
        cardFlying = true
        veiled = true
        switch ProcessInfo.processInfo.environment["CW_PUSH"] {
        case "ship":      path.append(ShipRoute(sailing: sailing))
        case "itinerary": path.append(ItineraryRoute(sailing: sailing))
        default: break
        }
    }
}
