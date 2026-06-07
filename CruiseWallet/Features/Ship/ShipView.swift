//
//  ShipView.swift
//  CruiseWallet
//
//  A dedicated ship screen (a premium addition — the RN app has no ship page),
//  pushed from the Voyage tab. Stretchy photo hero, identity line, a glass spec
//  grid, and an amenities list.
//

import SwiftUI

struct ShipView: View {
    let sailing: Sailing

    @Environment(\.dismiss) private var dismiss
    private let scrollSpace = "shipScroll"

    private var ship: Ship { sailing.ship }

    var body: some View {
        ZStack(alignment: .top) {
            TextureBackground()

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    body(content: shipBody)
                }
            }
            .coordinateSpace(name: scrollSpace)
            .ignoresSafeArea(edges: .top)

            HStack {
                backButton
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Hero

    private var hero: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(scrollSpace)).minY
            let stretch = max(0, minY)
            let h = 300 + stretch
            ZStack(alignment: .bottomLeading) {
                AssetImage(name: ship.photos.first ?? sailing.coverImageAsset, label: ship.name)
                    .frame(width: geo.size.width, height: h)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 6) {
                    Text(ship.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("\(ship.line) · \(ship.shipClass)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 42)
            }
            .frame(width: geo.size.width, height: h)
            .offset(y: -stretch)
        }
        .frame(height: 300)
    }

    private func body(content: some View) -> some View {
        content
            .background(TextureBackground())
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.top, -28)
    }

    // MARK: Body

    private var shipBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            photoStrip
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Specifications")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Ink.primary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    StatTile(symbol: "calendar", label: "Year built", value: "\(ship.yearBuilt)")
                    StatTile(symbol: "scalemass", label: "Gross tonnage", value: "\(ship.grossTonnage.formatted()) GT")
                    StatTile(symbol: "square.stack.3d.up", label: "Decks", value: "\(ship.decks)")
                    StatTile(symbol: "person.2", label: "Guests", value: ship.guestCapacity.formatted())
                    StatTile(symbol: "ruler", label: "Length", value: "\(ship.lengthMeters) m")
                    StatTile(symbol: "building.columns", label: "Class", value: ship.shipClass)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Onboard")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.Ink.primary)
                GlassCard(cornerRadius: Theme.Radius.card, padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(ship.amenities.enumerated()), id: \.element.id) { idx, a in
                            amenityRow(a)
                            if idx != ship.amenities.count - 1 {
                                Divider().background(Theme.Ink.hairline).padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(ship.photos.enumerated()), id: \.offset) { _, photo in
                    AssetImage(name: photo, label: ship.name)
                        .frame(width: 240, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .themeShadow(Theme.Shadow.soft)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func amenityRow(_ a: Amenity) -> some View {
        HStack(spacing: 14) {
            Image(systemName: a.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Palette.duskIndigo)
                .frame(width: 42, height: 42)
                .background(Theme.Palette.duskIndigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(a.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Ink.primary)
                Text(a.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Ink.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial.opacity(0.9), in: Circle())
                .background(Color.black.opacity(0.22), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 0.5))
        }
        .buttonStyle(.scale)
    }
}
