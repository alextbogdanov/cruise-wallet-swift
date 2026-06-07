//
//  MockStore.swift
//  CruiseWallet
//
//  Single source of truth for the mockup, injected via `.environmentObject`. Holds
//  the sample sailings and the welcome↔home gate. No persistence, no backend.
//

import SwiftUI

@MainActor
final class MockStore: ObservableObject {
    /// Welcome is shown until the user taps Get Started.
    @Published var hasEntered: Bool = false
    @Published var sailings: [Sailing]

    /// DEBUG launch hook: a sailing id to deep-link into on launch (for sim screenshots).
    /// Set via the `CW_OPEN_SAILING` environment variable.
    let openSailingOnLaunch: String?

    init() {
        self.sailings = MockData.sailings()
        let env = ProcessInfo.processInfo.environment
        // CW_START=home skips the welcome screen.
        if env["CW_START"] == "home" { self.hasEntered = true }
        self.openSailingOnLaunch = env["CW_OPEN_SAILING"]
        if openSailingOnLaunch != nil { self.hasEntered = true }
    }

    /// Sailings ordered soonest-first for the Apple-Wallet stack: the one happening
    /// *now* sits on top, then upcoming voyages by nearest departure, then completed
    /// ones (most recent first). This is the order the overlapping cascade reads in.
    var sortedSailings: [Sailing] {
        sailings.sorted { sortKey($0) < sortKey($1) }
    }

    /// A monotonic key that ranks active → upcoming → completed, breaking ties by
    /// proximity to today. Active wins outright; upcoming sorts by days-until;
    /// completed sorts by days-since (smaller = more recent).
    private func sortKey(_ s: Sailing) -> (Int, Int) {
        switch status(for: s) {
        case .during:            return (0, 0)
        case .before(let until): return (1, until)
        case .after(let since):  return (2, since)
        }
    }

    func status(for sailing: Sailing) -> CruiseStatus {
        CruiseStatus.of(departure: sailing.departureDate, length: sailing.length)
    }

    func delete(_ sailing: Sailing) {
        sailings.removeAll { $0.id == sailing.id }
    }

    func reset() {
        sailings = MockData.sailings()
    }
}
