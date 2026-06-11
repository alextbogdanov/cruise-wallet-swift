//
//  HomeView.swift
//  CruiseWallet
//
//  The wallet. An overlapping Apple-Wallet card stack (`WalletStack`) inside a
//  single native scroll view under a large "Cruise Wallet" title. Tapping a card
//  sets `selected` inside a `withAnimation`, which runs a TRUE shared-element
//  hero: the stack drops that card and `SailingPassView` (a full-screen overlay,
//  NOT a nav push) inserts a card with the same `matchedGeometryEffect` id, so
//  only the CARD flies to the top while the pass's layers fade on their own
//  staggered tracks.
//
//  Chrome: the system navigation bar is PERMANENTLY hidden at this root, and the
//  large title + collapsing inline header are recreated as plain content (the
//  title row scrolls with the cards; `header` pins an inline bar that fades in
//  past the collapse threshold, driven by the same scroll probe as the stack's
//  pull-to-fan). This is what kills the open/close layout jump: toggling the
//  system bar mutates the top safe-area inset (~96pt) mid-flight and re-layouts
//  everything against it. With no system bar EVER, the safe area is constant and
//  the pass simply fades in over home — nothing can move because no layout
//  changes, only opacity and the card's matched geometry.
//
//  The hero overlay must stay INSIDE this `NavigationStack`: `matchedGeometryEffect`
//  cannot bridge across the stack's UIKit hosting boundary (verified by frame
//  capture — a sibling overlay's card teleports and fades instead of flying).
//  Sub-pushes (View ship, full itinerary) ride this stack via
//  `NavigationLink(value:)`; pushed screens show normal bars over the hidden root.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MockStore

    @Namespace private var ns
    @State private var path = NavigationPath()
    /// The open pass, if any. Drives the shared-element hero (set inside a
    /// `withAnimation`, never via the nav path).
    @State private var selected: Sailing?
    @State private var pendingDelete: Sailing?
    @State private var showDebug = false

    /// Frame-matched to the Wallet capture: the card reaches its slot in ~0.15s
    /// and is settled by ~0.27s with a barely-there overshoot.
    private let heroSpring: Animation = .spring(response: 0.42, dampingFraction: 0.84)

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

                // Track: hero overlay. Only the card morphs (shared id); the
                // pass's own layers fade in on separate, staggered tracks.
                if let selected {
                    SailingPassView(
                        sailing: selected,
                        status: store.status(for: selected),
                        namespace: ns,
                        onClose: close
                    )
                    .zIndex(2)
                }
            }
            // No system bar at this root, ever — the title/header above are ours.
            // Pushed screens (ship / itinerary) still get normal system bars.
            .toolbar(.hidden, for: .navigationBar)
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

            if store.sailings.isEmpty {
                emptyState
            } else {
                WalletStack(
                    sailings: store.sortedSailings,
                    namespace: ns,
                    selected: selected,
                    overscroll: max(0, scrollOffset),
                    status: { store.status(for: $0) },
                    onTap: open,
                    onDelete: { pendingDelete = $0 }
                )
            }
        }
        .coordinateSpace(name: scrollSpace)
        .onPreferenceChange(ScrollMinYKey.self) { minY in
            // First reading establishes the rest position; the signed offset
            // tracks both the upward scroll (header collapse) and the live pull
            // (stack fan), so release springs back with the scroll's rubber-band.
            if restMinY == nil { restMinY = minY }
            let rest = restMinY ?? minY
            scrollOffset = minY - rest
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
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

    // MARK: Open / close (shared-element hero)

    private func open(_ sailing: Sailing) {
        withAnimation(heroSpring) { selected = sailing }
    }

    private func close() {
        withAnimation(heroSpring) { selected = nil }
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

    /// `CW_OPEN_SAILING=<id>` opens a pass on launch by setting `selected` (no
    /// animation — already-open for screenshots); `CW_PUSH=ship|itinerary` then
    /// pushes a sub-screen over it. `CW_TAB` is read by `SailingPassView` itself.
    private func applyLaunchHooks() {
        guard let id = store.openSailingOnLaunch,
              let sailing = store.sortedSailings.first(where: { $0.id == id }) else { return }
        selected = sailing
        switch ProcessInfo.processInfo.environment["CW_PUSH"] {
        case "ship":      path.append(ShipRoute(sailing: sailing))
        case "itinerary": path.append(ItineraryRoute(sailing: sailing))
        default: break
        }
    }
}
