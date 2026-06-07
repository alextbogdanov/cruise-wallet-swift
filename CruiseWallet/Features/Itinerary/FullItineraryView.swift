//
//  FullItineraryView.swift
//  CruiseWallet
//
//  The complete day-by-day itinerary, pushed from the open pass's Details tab. A
//  native large-title nav bar ("Itinerary") over the full glass timeline of
//  `ItineraryDayRow`s — header consistency with Home (the custom CollapsingHeader
//  is gone). Mirrors cruise-wallet/src/components/sailings/sailing-itinerary.tsx.
//

import SwiftUI

struct FullItineraryView: View {
    let sailing: Sailing

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Text("\(sailing.shipName) · \(sailing.days.count) days")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 14)

                ForEach(Array(sailing.days.enumerated()), id: \.element.id) { idx, day in
                    ItineraryDayRow(day: day, isFirst: idx == 0, isLast: idx == sailing.days.count - 1)
                        .staggeredReveal(index: min(idx, 8), baseDelay: 0.04, step: 0.04, haptic: false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(TextureBackground())
        .navigationTitle("Itinerary")
    }
}
