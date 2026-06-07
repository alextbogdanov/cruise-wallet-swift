//
//  MockData.swift
//  CruiseWallet
//
//  Sample sailings spanning all three statuses (before / during / after) so every
//  countdown + chart state is visible without a backend. Dates are computed relative
//  to "now" at launch, so the statuses stay correct whenever the app is run. Asset
//  names follow the fal.ai manifest convention (ship_*, port_*, line_*); until those
//  are generated, `AssetImage` shows labelled placeholders.
//

import SwiftUI

enum MockData {

    static func sailings(now: Date = Date()) -> [Sailing] {
        [
            mediterranean(now: now),   // before — departs in ~24 days
            caribbean(now: now),       // during — sailing right now (Day 3)
            norway(now: now),          // before — departs in ~96 days
            alaska(now: now),          // after  — ended ~30 days ago
        ]
    }

    // MARK: - Date helpers

    private static let cal = Calendar.current
    private static func day(_ offset: Int, from now: Date) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: offset, to: now) ?? now)
    }

    /// Build itinerary days from a compact tuple list.
    private static func days(
        from departure: Date,
        _ rows: [(port: String, region: String?, country: String?, arr: String?, dep: String?, allDay: Bool, notes: String?)]
    ) -> [SailingDay] {
        rows.enumerated().map { idx, r in
            SailingDay(
                dayNumber: idx + 1,
                date: cal.date(byAdding: .day, value: idx, to: departure),
                portName: r.port,
                region: r.region,
                country: r.country,
                arrivalTime: r.arr,
                departureTime: r.dep,
                allDay: r.allDay,
                fieldNotes: r.notes
            )
        }
    }

    // MARK: - Sailings

    private static func mediterranean(now: Date) -> Sailing {
        let dep = day(24, from: now)
        let ship = Ship(
            name: "Aurora of the Seas", line: "Celestia Cruises", shipClass: "Meridian Class",
            yearBuilt: 2022, grossTonnage: 168_800, decks: 18, guestCapacity: 5_600, lengthMeters: 362,
            amenities: [
                Amenity(symbol: "fork.knife", title: "20 Dining Venues", detail: "From chef's table to late-night ramen"),
                Amenity(symbol: "figure.pool.swim", title: "Resort Deck", detail: "4 pools · 9 whirlpools"),
                Amenity(symbol: "theatermasks", title: "Aurora Theater", detail: "1,400-seat West End productions"),
                Amenity(symbol: "sparkles", title: "Sea Spa", detail: "Thermal suite & thalassotherapy"),
                Amenity(symbol: "music.mic", title: "The Promenade", detail: "Live jazz nightly"),
            ],
            photos: ["ship_aurora_1", "ship_aurora_2", "ship_aurora_3"]
        )
        return Sailing(
            id: "med-aurora",
            name: "7-Night Western Mediterranean",
            shipName: "Aurora of the Seas",
            cruiseLineName: "Celestia Cruises",
            cruiseLineLogoAsset: "line_celestia",
            departureDate: dep, length: 7,
            coverImageAsset: "port_santorini",
            cardBackgroundAsset: "port_santorini",
            embarkPort: "Barcelona", disembarkPort: "Barcelona",
            ship: ship,
            days: days(from: dep, [
                ("Barcelona", "Catalonia", "Spain", nil, "17:00", false, "Embarkation opens at noon. Tapas crawl on La Rambla before all-aboard."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Naples", "Campania", "Italy", "07:00", "18:00", false, "Gateway to Pompeii and the Amalfi Coast."),
                ("Rome (Civitavecchia)", "Lazio", "Italy", "06:30", "19:00", false, "90 min by shuttle to the Eternal City."),
                ("Florence (Livorno)", "Tuscany", "Italy", "08:00", "20:00", false, nil),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Palma de Mallorca", "Balearic Islands", "Spain", "09:00", "17:00", false, "Gothic cathedral and hidden cove beaches."),
                ("Barcelona", "Catalonia", "Spain", "06:00", nil, false, "Disembarkation from 7:00 AM."),
            ])
        )
    }

    private static func caribbean(now: Date) -> Sailing {
        let dep = day(-2, from: now)   // Day 3 of 7 today → ACTIVE
        let ship = Ship(
            name: "Coral Mirage", line: "Azure Line", shipClass: "Lagoon Class",
            yearBuilt: 2024, grossTonnage: 142_000, decks: 16, guestCapacity: 4_200, lengthMeters: 330,
            amenities: [
                Amenity(symbol: "water.waves", title: "AquaPark", detail: "Six slides & a surf simulator"),
                Amenity(symbol: "sun.max", title: "Serenity Deck", detail: "Adults-only infinity edge"),
                Amenity(symbol: "fork.knife", title: "Island Eats", detail: "14 venues incl. open-air grill"),
                Amenity(symbol: "guitars", title: "Calypso Lounge", detail: "Steel-drum sessions at sunset"),
                Amenity(symbol: "snowflake", title: "Ice Studio", detail: "Skating rink & evening shows"),
            ],
            photos: ["ship_coral_1", "ship_coral_2", "ship_coral_3"]
        )
        return Sailing(
            id: "car-coral",
            name: "7-Night Eastern Caribbean",
            shipName: "Coral Mirage",
            cruiseLineName: "Azure Line",
            cruiseLineLogoAsset: "line_azure",
            departureDate: dep, length: 7,
            coverImageAsset: "port_stmaarten",
            cardBackgroundAsset: "port_stmaarten",
            embarkPort: "Miami", disembarkPort: "Miami",
            ship: ship,
            days: days(from: dep, [
                ("Miami", "Florida", "USA", nil, "16:30", false, "Set sail past South Beach at golden hour."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("San Juan", nil, "Puerto Rico", "10:00", "19:00", false, "Old San Juan's blue cobblestones and El Morro."),
                ("Charlotte Amalie", nil, "U.S. Virgin Islands", "08:00", "17:00", false, "Snorkel Trunk Bay, St. John."),
                ("Philipsburg", nil, "St. Maarten", "09:00", "18:00", false, "Maho Beach plane-spotting."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("CocoCay", nil, "Bahamas", "07:30", "16:00", false, "Private island day — Oasis Lagoon."),
                ("Miami", "Florida", "USA", "06:00", nil, false, "Disembarkation from 7:00 AM."),
            ])
        )
    }

    private static func norway(now: Date) -> Sailing {
        let dep = day(96, from: now)
        let ship = Ship(
            name: "Northern Lyric", line: "Fjordline Voyages", shipClass: "Aurora Class",
            yearBuilt: 2021, grossTonnage: 113_000, decks: 14, guestCapacity: 2_900, lengthMeters: 300,
            amenities: [
                Amenity(symbol: "binoculars", title: "Observation Deck", detail: "360° glass-walled lounge"),
                Amenity(symbol: "fork.knife", title: "Nordic Table", detail: "New-Nordic tasting menus"),
                Amenity(symbol: "flame", title: "Sauna & Snow Room", detail: "Authentic Finnish thermal circuit"),
                Amenity(symbol: "camera", title: "Aurora Watch", detail: "Naturalist-led night viewings"),
            ],
            photos: ["ship_northern_1", "ship_northern_2"]
        )
        return Sailing(
            id: "nor-lyric",
            name: "9-Night Norwegian Fjords",
            shipName: "Northern Lyric",
            cruiseLineName: "Fjordline Voyages",
            cruiseLineLogoAsset: "line_fjordline",
            departureDate: dep, length: 9,
            coverImageAsset: "port_geiranger",
            cardBackgroundAsset: "port_geiranger",
            embarkPort: "Copenhagen", disembarkPort: "Copenhagen",
            ship: ship,
            days: days(from: dep, [
                ("Copenhagen", "Zealand", "Denmark", nil, "18:00", false, "Nyhavn dinner before all-aboard."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Geiranger", nil, "Norway", "08:00", "18:00", false, "Sail the UNESCO Geirangerfjord."),
                ("Ålesund", nil, "Norway", "07:00", "16:00", false, "Art Nouveau town from Mount Aksla."),
                ("Flåm", nil, "Norway", "09:00", "19:00", false, "The Flåm Railway through waterfalls."),
                ("Bergen", nil, "Norway", "08:00", "17:00", false, "Bryggen wharf and the fish market."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Stavanger", nil, "Norway", "10:00", "18:00", false, "Hike toward Pulpit Rock."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Copenhagen", "Zealand", "Denmark", "06:30", nil, false, "Disembarkation from 7:00 AM."),
            ])
        )
    }

    private static func alaska(now: Date) -> Sailing {
        let dep = day(-40, from: now)   // ended ~30 days ago → COMPLETED
        let ship = Ship(
            name: "Glacier Sovereign", line: "Polar Star Cruises", shipClass: "Frontier Class",
            yearBuilt: 2019, grossTonnage: 99_800, decks: 13, guestCapacity: 2_500, lengthMeters: 294,
            amenities: [
                Amenity(symbol: "mountain.2", title: "Glass Solarium", detail: "Heated, all-weather viewing"),
                Amenity(symbol: "fork.knife", title: "Wild Catch", detail: "Daily Alaskan seafood market"),
                Amenity(symbol: "leaf", title: "Naturalist Center", detail: "Onboard rangers & talks"),
                Amenity(symbol: "cup.and.saucer", title: "Summit Lounge", detail: "Hot toddies at the glaciers"),
            ],
            photos: ["ship_glacier_1", "ship_glacier_2"]
        )
        return Sailing(
            id: "alk-sovereign",
            name: "7-Night Alaska Inside Passage",
            shipName: "Glacier Sovereign",
            cruiseLineName: "Polar Star Cruises",
            cruiseLineLogoAsset: "line_polarstar",
            departureDate: dep, length: 7,
            coverImageAsset: "port_glacierbay",
            cardBackgroundAsset: "port_glacierbay",
            embarkPort: "Seattle", disembarkPort: "Seattle",
            ship: ship,
            days: days(from: dep, [
                ("Seattle", "Washington", "USA", nil, "16:00", false, "Pike Place chowder before departure."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Juneau", "Alaska", "USA", "10:00", "20:00", false, "Mendenhall Glacier & whale watching."),
                ("Skagway", "Alaska", "USA", "07:00", "17:00", false, "White Pass scenic railway."),
                ("Glacier Bay", "Alaska", "USA", nil, nil, true, "A full scenic-cruising day among tidewater glaciers."),
                ("Ketchikan", "Alaska", "USA", "07:00", "13:00", false, "Misty Fjords floatplane."),
                ("At Sea", nil, nil, nil, nil, false, nil),
                ("Seattle", "Washington", "USA", "06:00", nil, false, "Disembarkation from 7:00 AM."),
            ])
        )
    }

    // MARK: - Widgets-tab photo styles

    static let photoStyles: [PhotoStyle] = [
        PhotoStyle(name: "Ocean", symbol: "water.waves", colors: [Color(hex: "#5FA3C2"), Color(hex: "#245876")]),
        PhotoStyle(name: "Sunset", symbol: "sun.haze", colors: [Color(hex: "#FF8A6B"), Color(hex: "#B5476B")]),
        PhotoStyle(name: "Minimal", symbol: "circle.lefthalf.filled", colors: [Color(hex: "#F2F2F7"), Color(hex: "#C7C7CC")]),
        PhotoStyle(name: "Night Sky", symbol: "moon.stars", colors: [Color(hex: "#1A1A2E"), Color(hex: "#2E6C92")]),
        PhotoStyle(name: "Tropical", symbol: "leaf", colors: [Color(hex: "#2E8B57"), Color(hex: "#5FA3C2")]),
        PhotoStyle(name: "Nautical", symbol: "sailboat", colors: [Color(hex: "#245876"), Color(hex: "#1A1A2E")]),
    ]
}
