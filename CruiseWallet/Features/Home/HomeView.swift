//
//  HomeView.swift
//  CruiseWallet
//
//  The wallet. An overlapping Apple-Wallet card stack (`WalletStack`) under a
//  native large "Cruise Wallet" title that collapses to a centered inline title
//  with the nav-bar blur as the stack scrolls. A native trailing toolbar button
//  opens the debug menu when closed. Tapping a card lifts it to `OpenPassView`
//  (a matched-geometry morph) while the rest of the stack recedes; opening a pass
//  hides the nav bar so the full-screen overlay (which carries its own glass ✕)
//  reads cleanly. This view owns the NavigationStack, the shared `@Namespace`,
//  and the push destinations reached from the open pass.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: MockStore

    @Namespace private var ns
    @State private var path = NavigationPath()
    @State private var openSailing: Sailing?
    @State private var pendingDelete: Sailing?
    @State private var showDebug = false

    private var isOpen: Bool { openSailing != nil }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                TextureBackground()
                WalletStack(
                    sailings: store.sortedSailings,
                    namespace: ns,
                    openSailing: $openSailing,
                    status: { store.status(for: $0) },
                    onTap: open,
                    onDelete: { pendingDelete = $0 }
                )
                .scaleEffect(isOpen ? 0.93 : 1)
                // Fade the live stack out during the open morph. The open pass's
                // backdrop FADES in (it isn't opaque mid-transition), so without
                // this the 4 foil+glass cards stay fully composited under a
                // translucent veil — both visually wrong (cards show through) and
                // the dominant source of jank (5× offscreen passes per frame).
                .opacity(isOpen ? 0 : 1)

                if store.sailings.isEmpty {
                    emptyState
                        .opacity(isOpen ? 0 : 1)
                }
            }
            .overlay { openPassOverlay }
            .navigationTitle("Cruise Wallet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showDebug = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            // Hide the bar while a pass is open so the full-screen overlay reads cleanly.
            .toolbar(isOpen ? .hidden : .visible, for: .navigationBar)
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

    // MARK: Open pass overlay

    @ViewBuilder private var openPassOverlay: some View {
        if let sailing = openSailing {
            OpenPassView(
                sailing: sailing,
                status: store.status(for: sailing),
                namespace: ns,
                onClose: close
            )
            // Insert the pass INSTANTLY (no default .opacity fade on the whole
            // subtree). Its opaque backdrop then occludes the home stack from
            // frame one, so the morph is a pure matched-geometry LIFT of the card
            // — not a full-screen cross-dissolve. The detail content does its own
            // delayed fade-in from inside OpenPassView.
            .transition(.identity)
        }
    }

    // MARK: Interaction

    private func open(_ sailing: Sailing) {
        Haptics.impact(.light)
        withAnimation(Theme.Motion.wallet) { openSailing = sailing }
    }

    private func close() {
        withAnimation(Theme.Motion.wallet) { openSailing = nil }
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
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    // MARK: DEBUG launch hooks

    /// `CW_OPEN_SAILING=<id>` expands a pass in place (no animation, so it's already
    /// open for screenshots); `CW_PUSH=ship|itinerary` then pushes a sub-screen over
    /// it. `CW_TAB` is read by `OpenPassView` itself.
    private func applyLaunchHooks() {
        guard let id = store.openSailingOnLaunch,
              let sailing = store.sortedSailings.first(where: { $0.id == id }) else { return }
        openSailing = sailing
        switch ProcessInfo.processInfo.environment["CW_PUSH"] {
        case "ship":      path.append(ShipRoute(sailing: sailing))
        case "itinerary": path.append(ItineraryRoute(sailing: sailing))
        default: break
        }
    }
}
