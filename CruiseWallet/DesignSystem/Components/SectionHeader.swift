//
//  SectionHeader.swift
//  Cruzero
//
//  Big editorial titles (welcome, explainers, every onboarding step) plus a
//  lighter section variant for in-screen groupings. Uses a serif display face
//  for the warm, premium "Mediterranean editorial" tone.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var alignment: HorizontalAlignment = .leading
    /// `.display` = big hero title; `.section` = smaller in-screen header.
    var size: Size = .display

    enum Size { case display, section }

    @Environment(\.accentContext) private var accent

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(Theme.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: size == .display ? 17 : 15, weight: .medium))
                    .foregroundStyle(Theme.Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .multilineTextAlignment(textAlignment)
    }

    private var titleFont: Font {
        switch size {
        case .display: return .system(size: 30, weight: .bold, design: .serif)
        case .section: return .system(size: 20, weight: .bold)
        }
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    private var textAlignment: TextAlignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }
}
