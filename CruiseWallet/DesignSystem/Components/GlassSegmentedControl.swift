//
//  GlassSegmentedControl.swift
//  CruiseWallet
//
//  A custom segmented control (not `Picker`) with a matched-geometry sliding accent
//  pill, on a glass capsule track. Drives the boarding pass's Voyage / Widgets tabs.
//

import SwiftUI
import UIKit

struct GlassSegmentedControl: View {
    let items: [String]
    @Binding var selection: Int

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                let isSelected = selection == i
                Text(items[i])
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Theme.Ink.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Theme.Palette.duskIndigo)
                                .matchedGeometryEffect(id: "pill", in: pill)
                                .shadow(color: Theme.Palette.duskIndigo.opacity(0.35), radius: 8, y: 3)
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        guard selection != i else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(Theme.Motion.snappy) { selection = i }
                    }
            }
        }
        .padding(4)
        .compatibleGlassCapsule(tint: Theme.Palette.duskIndigo.opacity(0.06))
    }
}
