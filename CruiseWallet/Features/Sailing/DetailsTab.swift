//
//  DetailsTab.swift
//  CruiseWallet
//
//  The "back of the pass" — the Details tab of the open pass. Deliberately minimal
//  (no stat tiles, no charts): the sailing's marketing name, a Wallet-style field
//  list (label-over-value), a row into the dedicated Ship screen, and a 3-day
//  itinerary preview with a row into the full Itinerary. The two rows are
//  `NavigationLink(value:)`s resolved by Home's stack, so they push over the open
//  pass and pop back to it.
//

import SwiftUI

struct DetailsTab: View {
    let sailing: Sailing

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(sailing.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            fieldList

            NavigationLink(value: ShipRoute(sailing: sailing)) {
                linkRow(symbol: "sailboat", title: "View ship", subtitle: sailing.shipName)
            }
            .buttonStyle(.scale)

            itinerarySection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Field list (Wallet "back of pass")

    private var fieldList: some View {
        GlassCard(cornerRadius: Theme.Radius.card, padding: 4) {
            VStack(spacing: 0) {
                field("Dates", Formatters.range(from: sailing.departureDate, nights: sailing.length))
                rowDivider
                field("Cruise line", sailing.cruiseLineName)
                rowDivider
                field("Ship", sailing.shipName)
            }
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.Ink.tertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var rowDivider: some View {
        Divider().background(Theme.Ink.hairline).padding(.leading, 14)
    }

    // MARK: Itinerary preview

    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Itinerary")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.Ink.primary)

            let preview = Array(sailing.days.prefix(3))
            VStack(spacing: 0) {
                ForEach(Array(preview.enumerated()), id: \.element.id) { idx, day in
                    ItineraryDayRow(day: day, isFirst: idx == 0, isLast: idx == preview.count - 1)
                }
            }

            NavigationLink(value: ItineraryRoute(sailing: sailing)) {
                linkRow(symbol: "map", title: "View full itinerary",
                        subtitle: "\(sailing.days.count) days")
            }
            .buttonStyle(.scale)
        }
    }

    // MARK: Link row

    private func linkRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Palette.duskIndigo)
                .frame(width: 42, height: 42)
                .background(Theme.Palette.duskIndigo.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Ink.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Ink.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Ink.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .compatibleGlassStatic(tint: Theme.Palette.duskIndigo.opacity(0.06), cornerRadius: Theme.Radius.card)
    }
}
