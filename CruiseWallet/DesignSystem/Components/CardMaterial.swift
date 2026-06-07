//
//  CardMaterial.swift
//  CruiseWallet
//
//  The `foilCardMaterial` modifier — a metallic-foil finish for card surfaces.
//  It layers a genuine Metal sheen (`foilSheen`, see CardMaterial.metal) over the
//  content, plus a fine edge bevel (white hairline top-leading → dark hairline
//  bottom-trailing) and a tasteful emboss from the existing shadow ladder.
//
//  The sheen's specular streak tracks a `light` direction (a tilt vector in
//  ~-1...1). Honors Reduce Motion by freezing the streak to centered (`.zero`),
//  while the grain, bevel, and emboss still render so the card keeps its finish.
//
//  FROZEN CONTRACT (other agents code against this exact signature):
//
//      func foilCardMaterial(light: CGSize = .zero,
//                            cornerRadius: CGFloat = Theme.Radius.card) -> some View
//

import SwiftUI

private struct FoilCardMaterial: ViewModifier {
    /// Tilt-driven streak direction, roughly -1...1 (width = horizontal,
    /// height = vertical). `.zero` = centered/static streak.
    var light: CGSize
    var cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    func body(content: Content) -> some View {
        // When Reduce Motion is on, freeze the streak to centered.
        let effectiveLight = reduceMotion ? .zero : light

        content
            // 1) Metal foil sheen as a highlight layer over the photo.
            .overlay {
                GeometryReader { geo in
                    let size = geo.size
                    Rectangle()
                        .fill(.black)   // colorEffect computes its own RGBA
                        .colorEffect(
                            ShaderLibrary.foilSheen(
                                .float2(Float(effectiveLight.width),
                                        Float(effectiveLight.height)),
                                .float2(Float(size.width), Float(size.height))
                            )
                        )
                        .blendMode(.plusLighter)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            // 2) Fine edge bevel — white hairline (top-leading) → dark
            //    hairline (bottom-trailing) traces the rounded edge.
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .black.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
            // Keep the whole lockup clipped to the card silhouette.
            .clipShape(shape)
            // 3) Emboss via the existing shadow ladder.
            .themeShadow(Theme.Shadow.soft)
    }
}

extension View {
    /// Apply the metallic-foil card finish: a Metal brushed-metal sheen whose
    /// specular streak tracks `light` (a tilt vector, ~-1...1), plus an edge
    /// bevel and a soft emboss. Honors Reduce Motion (streak freezes centered).
    ///
    /// - Parameters:
    ///   - light: Tilt direction the specular streak moves toward. `width` is
    ///     horizontal (−left … +right), `height` vertical (−up … +down).
    ///   - cornerRadius: Corner radius of the card silhouette.
    func foilCardMaterial(light: CGSize = .zero,
                          cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(FoilCardMaterial(light: light, cornerRadius: cornerRadius))
    }
}

// MARK: - Preview

#Preview("Foil card material") {
    @Previewable @State var light: CGSize = .zero

    VStack(spacing: 28) {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.Palette.duskIndigoDeep,
                             Theme.Palette.duskIndigo,
                             Theme.Palette.tealLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 320, height: 200)
            .foilCardMaterial(light: light)
            .overlay(alignment: .bottomLeading) {
                Text("CRUISE WALLET")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(18)
                    .allowsHitTesting(false)
            }

        VStack(spacing: 12) {
            HStack {
                Text("X")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Slider(value: $light.width, in: -1...1)
            }
            HStack {
                Text("Y")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Slider(value: $light.height, in: -1...1)
            }
            Text(String(format: "light = (%.2f, %.2f)", light.width, light.height))
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.backgroundGradient)
}
