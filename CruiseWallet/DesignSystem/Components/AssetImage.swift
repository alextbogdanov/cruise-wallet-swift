//
//  AssetImage.swift
//  CruiseWallet
//
//  Resilient image view. If a named image exists in the asset catalog (imported by
//  the fal.ai pipeline) it's drawn; otherwise a labelled accent-gradient placeholder
//  stands in, so the app keeps building and every photographic slot reads as
//  intentional until `FAL_KEY` is pasted and assets are generated.
//

import SwiftUI
import UIKit

struct AssetImage: View {
    let name: String
    /// Shown on the placeholder so unfilled slots are self-documenting.
    var label: String? = nil
    var contentMode: ContentMode = .fill

    private var exists: Bool { UIImage(named: name) != nil }

    var body: some View {
        if exists {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.tealLight, Theme.Palette.duskIndigo, Theme.Palette.duskIndigoDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // A soft diagonal sheen so the placeholder still feels like a photo plate.
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
            )
            VStack(spacing: 6) {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
}
