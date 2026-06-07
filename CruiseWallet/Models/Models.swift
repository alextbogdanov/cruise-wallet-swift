//
//  Models.swift
//  CruiseWallet
//
//  Plain-Swift mock models mirroring the cruise-wallet RN app's `UserSailing` /
//  `SailingDay` shapes (src/types/sailing.d.ts, convex/schema.ts). UI-only — no
//  backend. `Ship` is a premium addition powering the new Ship screen (the source
//  has no rich ship table). `CruiseStatus` is ported verbatim in spirit from
//  src/utilities/cruise-status.ts, plus a `progressFraction` that drives the charts.
//

import SwiftUI

// MARK: - Sailing

struct Sailing: Identifiable, Hashable {
    let id: String
    /// The sailing's marketing name (e.g. "7-Night Western Mediterranean") — the
    /// section title on the open pass's Details tab.
    let name: String
    let shipName: String
    let cruiseLineName: String
    /// Asset name for the cruise-line logo tile (placeholder until fal.ai assets land).
    let cruiseLineLogoAsset: String?
    let departureDate: Date
    /// Nights.
    let length: Int
    /// Full-bleed ship/destination photo asset name.
    let coverImageAsset: String
    /// Optional AI-generated card background; falls back to `coverImageAsset`.
    let cardBackgroundAsset: String?
    let embarkPort: String
    let disembarkPort: String
    let ship: Ship
    let days: [SailingDay]

    var backgroundAsset: String { cardBackgroundAsset ?? coverImageAsset }

    static func == (lhs: Sailing, rhs: Sailing) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // Derived voyage stats (precomputed-friendly; cheap).
    var portCount: Int { days.filter { !$0.isAtSea }.count }
    var seaDayCount: Int { days.filter { $0.isAtSea }.count }
}

// MARK: - Sailing day

struct SailingDay: Identifiable, Equatable {
    let id = UUID()
    let dayNumber: Int
    let date: Date?
    let portName: String
    let region: String?
    let country: String?
    /// "HH:mm" 24h, matching the RN source's raw times.
    let arrivalTime: String?
    let departureTime: String?
    let allDay: Bool
    let fieldNotes: String?

    var isAtSea: Bool { portName.lowercased() == "at sea" }
}

// MARK: - Ship

struct Ship: Equatable {
    let name: String
    let line: String
    let shipClass: String
    let yearBuilt: Int
    /// Gross tonnage (GT).
    let grossTonnage: Int
    let decks: Int
    let guestCapacity: Int
    let lengthMeters: Int
    let amenities: [Amenity]
    /// Photo asset names for the ship gallery.
    let photos: [String]
}

struct Amenity: Identifiable, Equatable {
    let id = UUID()
    let symbol: String   // SF Symbol
    let title: String
    let detail: String
}

// MARK: - Cruise status (ported from cruise-status.ts)

enum CruiseStatus: Equatable {
    case before(daysUntil: Int)
    case during(dayNumber: Int, totalDays: Int)
    case after(daysSince: Int)

    /// Relative phase of `departure`+`length` against `now` (both day-truncated),
    /// mirroring `getCruiseStatus`.
    static func of(departure: Date, length: Int, now: Date = Date()) -> CruiseStatus {
        let cal = Calendar.current
        let dep = cal.startOfDay(for: departure)
        let today = cal.startOfDay(for: now)
        let diffDays = cal.dateComponents([.day], from: dep, to: today).day ?? 0

        if diffDays < 0 {
            return .before(daysUntil: abs(diffDays))
        }
        if diffDays <= length {
            return .during(dayNumber: diffDays + 1, totalDays: length)
        }
        let end = cal.date(byAdding: .day, value: length, to: dep) ?? dep
        let since = cal.dateComponents([.day], from: end, to: today).day ?? 0
        return .after(daysSince: since)
    }

    /// Compact single-line string — `getCruiseCountdownText`.
    var countdownText: String {
        switch self {
        case .before(let d): return "\(d) day\(d == 1 ? "" : "s") to go"
        case .during(let n, let total): return "Day \(n) of \(total)"
        case .after(let d): return "\(d) day\(d == 1 ? "" : "s") ago"
        }
    }

    /// Big numeral — `getCruiseStatusLabel`.
    var bigLabel: String {
        switch self {
        case .before(let d): return "\(d)"
        case .during(let n, _): return "Day \(n)"
        case .after(let d): return "\(d)"
        }
    }

    /// Subtitle under the numeral — `getCruiseStatusSubtitle`.
    var subtitle: String {
        switch self {
        case .before: return "days to departure"
        case .during(_, let total): return "of \(total)"
        case .after(let d): return "day\(d == 1 ? "" : "s") ago"
        }
    }

    /// Status chip text + color (matches the RN `getStatusLabel`).
    var chip: (text: String, color: Color) {
        switch self {
        case .before: return ("UPCOMING", Color(hex: "#007AFF"))
        case .during: return ("ACTIVE", Color(hex: "#34C759"))
        case .after:  return ("COMPLETED", Color(hex: "#8E8E93"))
        }
    }

    /// 0…1 progress across the trip (kept for widget previews / future use).
    var progressFraction: Double {
        switch self {
        case .before: return 0
        case .during(let n, let total): return total > 0 ? min(1, Double(n) / Double(total)) : 0
        case .after: return 1
        }
    }

    var isActive: Bool { if case .during = self { return true } else { return false } }
}

// MARK: - Photo styles (Widgets tab picker)

struct PhotoStyle: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let symbol: String
    /// Two-stop gradient preview.
    let colors: [Color]
}
