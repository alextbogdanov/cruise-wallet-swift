//
//  ItineraryDayRow.swift
//  CruiseWallet
//
//  One day on the voyage timeline: a continuous accent rail with a port dot (solid)
//  or at-sea dot (hollow), beside a glass day card with the port, region, date,
//  arrival/departure times (or All Day) and any field notes. Shared by the Voyage
//  tab preview and the full Itinerary screen. Mirrors
//  cruise-wallet/src/components/sailings/sailing-itinerary.tsx.
//

import SwiftUI

struct ItineraryDayRow: View {
    let day: SailingDay
    let isFirst: Bool
    let isLast: Bool

    private var dotCenterY: CGFloat { 26 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            rail
            dayCard
                .padding(.bottom, isLast ? 0 : 12)
        }
    }

    // MARK: Rail

    private var rail: some View {
        ZStack(alignment: .top) {
            // Continuous vertical line through the gap.
            if !(isFirst && isLast) {
                Rectangle()
                    .fill(Theme.Ink.faint)
                    .frame(width: 2)
                    .padding(.top, isFirst ? dotCenterY : 0)
            }
            dot
                .padding(.top, dotCenterY - dotSize / 2)
        }
        .frame(width: 16)
    }

    private var dotSize: CGFloat { day.isAtSea ? 12 : 14 }

    @ViewBuilder private var dot: some View {
        if day.isAtSea {
            Circle()
                .strokeBorder(Theme.Ink.tertiary, lineWidth: 2)
                .background(Circle().fill(Theme.Palette.bgMid))
                .frame(width: dotSize, height: dotSize)
        } else {
            Circle()
                .fill(Theme.Palette.duskIndigo)
                .frame(width: dotSize, height: dotSize)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: Theme.Palette.duskIndigo.opacity(0.4), radius: 3, y: 1)
        }
    }

    // MARK: Day card

    private var dayCard: some View {
        GlassCard(cornerRadius: Theme.Radius.tile, padding: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Day \(day.dayNumber)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.duskIndigo)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(day.portName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.Ink.primary)
                    if let region = day.region, !day.isAtSea {
                        Text(region)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.Ink.tertiary)
                    }
                }

                if let date = day.date {
                    Text(Formatters.day(date))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Ink.secondary)
                }

                times
                    .padding(.top, 6)

                if let notes = day.fieldNotes {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Ink.tertiary)
                        .padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var times: some View {
        if day.allDay {
            Text("ALL DAY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.Ink.tertiary)
        } else {
            let arr = Formatters.time(day.arrivalTime)
            let dep = Formatters.time(day.departureTime)
            if arr != nil || dep != nil {
                HStack(spacing: 28) {
                    if let arr { timeCell("ARRIVAL", arr) }
                    if let dep { timeCell("DEPARTURE", dep) }
                }
            }
        }
    }

    private func timeCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Theme.Ink.tertiary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Ink.primary)
        }
    }
}
