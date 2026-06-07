//
//  Formatters.swift
//  CruiseWallet
//
//  Shared, cached date/time formatters (cheap `body`, no per-row allocation).
//

import Foundation

enum Formatters {
    /// "Jan 15, 2025"
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// "Monday, Jan 15"
    static let dayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    /// "Jan 15"
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func medium(_ date: Date?) -> String {
        guard let date else { return "TBD" }
        return mediumDate.string(from: date)
    }

    static func day(_ date: Date?) -> String {
        guard let date else { return "" }
        return dayDate.string(from: date)
    }

    /// "17:00" → "5:00 PM"
    static func time(_ hm: String?) -> String? {
        guard let hm, hm.contains(":") else { return nil }
        let parts = hm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]) else { return nil }
        let ampm = h >= 12 ? "PM" : "AM"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12):\(parts[1]) \(ampm)"
    }

    /// "Jan 15 – Jan 22" departure → return range.
    static func range(from departure: Date, nights: Int) -> String {
        let end = Calendar.current.date(byAdding: .day, value: nights, to: departure) ?? departure
        return "\(shortDate.string(from: departure)) – \(shortDate.string(from: end))"
    }
}
