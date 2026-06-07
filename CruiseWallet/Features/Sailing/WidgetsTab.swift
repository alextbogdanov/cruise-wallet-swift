//
//  WidgetsTab.swift
//  CruiseWallet
//
//  The redesigned widgets surface (cruise-wallet/src/components/sailings/
//  widgets-section.tsx + photo-style-selector.tsx + card-background-history.tsx):
//  glass home-screen widget previews, a photo-style picker, and the generated
//  background history. Visual/mocked only — no generation.
//

import SwiftUI
import UIKit

struct WidgetsTab: View {
    let sailing: Sailing

    @State private var selectedStyle: UUID

    init(sailing: Sailing) {
        self.sailing = sailing
        _selectedStyle = State(initialValue: MockData.photoStyles.first?.id ?? UUID())
    }

    private var status: CruiseStatus {
        CruiseStatus.of(departure: sailing.departureDate, length: sailing.length)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Home screen widgets")
            HStack(spacing: 14) {
                WidgetPreview(sailing: sailing, status: status, size: .small)
                WidgetPreview(sailing: sailing, status: status, size: .medium)
            }

            sectionTitle("Photo style")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MockData.photoStyles) { style in
                        PhotoStyleChip(style: style, isSelected: selectedStyle == style.id)
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(Theme.Motion.snappy) { selectedStyle = style.id }
                            }
                    }
                }
                .padding(.horizontal, 2)
            }

            sectionTitle("Background history")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    AssetImage(name: "\(sailing.backgroundAsset)_v\(i)", label: "Style \(i + 1)")
                        .frame(height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Ink.hairline, lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.Ink.primary)
    }
}

// MARK: - Widget preview

private struct WidgetPreview: View {
    let sailing: Sailing
    let status: CruiseStatus
    enum Size { case small, medium }
    let size: Size

    private var dimension: CGSize {
        switch size {
        case .small:  return CGSize(width: 150, height: 150)
        case .medium: return CGSize(width: 0, height: 150) // flexible width
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AssetImage(name: sailing.backgroundAsset, label: sailing.embarkPort)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 3) {
                Text(status.bigLabel)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(status.subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
                Text(sailing.shipName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: size == .small ? dimension.width : nil, height: dimension.height)
        .frame(maxWidth: size == .medium ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .themeShadow(Theme.Shadow.medium)
    }
}

// MARK: - Photo style chip

private struct PhotoStyleChip: View {
    let style: PhotoStyle
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: style.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.Palette.duskIndigo : Theme.Ink.hairline, lineWidth: isSelected ? 2.5 : 1)
            )
            Text(style.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Theme.Palette.duskIndigo : Theme.Ink.secondary)
        }
    }
}
