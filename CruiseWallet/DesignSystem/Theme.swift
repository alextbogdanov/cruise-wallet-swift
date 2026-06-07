//
//  Theme.swift
//  Cruzero
//
//  The Cruzero design tokens — clean, Hinge-adjacent, near-white surfaces with a
//  warm editorial voice. Glass/motion intent ported from Sherlock.
//
//  `AccentContext` is an environment value that flips the app between a
//  pre-sailing identity (future-tense, discovery-led) and an onboard identity
//  (present-tense, live-dashboard-led). Both modes share ONE accent palette
//  (softened dusk indigo/teal) — the mode drives copy, layout, and the tab set,
//  not color. Components read the accent from the environment, so the same
//  `PrimaryCTAButton`/`PillChip`/etc. work in both modes with no branching.
//

import SwiftUI

// MARK: - Accent Context (cool pre-sailing ↔ warm onboard)

/// Drives the active mode (copy/layout/tabs). In production this is chosen
/// automatically (today ∈ sailing dates → `.onboard`); in the mockup it's
/// flipped via the debug menu. Both modes share one accent palette.
enum AccentContext: String, CaseIterable, Identifiable {
    case preSailing   // discovery-led, future-tense
    case onboard      // live-dashboard-led, present-tense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preSailing: return "Pre-sailing"
        case .onboard:    return "Onboard"
        }
    }

    // One palette for both modes — the mode now drives copy/layout/tabs, not
    // color. (Kept as `AccentContext` properties so every component keeps reading
    // the accent through the environment, unchanged.)

    /// Primary accent — used for CTAs, selected states, key text.
    var primary: Color { Theme.Palette.duskIndigo }

    /// Lighter accent — gradients, secondary fills, glows.
    var primaryLight: Color { Theme.Palette.tealLight }

    /// Deep accent — pressed states, deep gradient stops.
    var primaryDeep: Color { Theme.Palette.duskIndigoDeep }

    /// Complementary pop color.
    var secondary: Color { Theme.Palette.coral }

    /// Diagonal accent gradient for glossy CTAs / heroes.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryLight, primary, primaryDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Colored glow (for accent shadows under CTAs and active cards).
    var glow: Color { primary.opacity(0.35) }
}

// MARK: - Environment plumbing

private struct AccentContextKey: EnvironmentKey {
    static let defaultValue: AccentContext = .preSailing
}

extension EnvironmentValues {
    var accentContext: AccentContext {
        get { self[AccentContextKey.self] }
        set { self[AccentContextKey.self] = newValue }
    }
}

extension View {
    /// Inject the active accent so all design-system components recolor.
    func accentContext(_ context: AccentContext) -> some View {
        environment(\.accentContext, context)
    }
}

// MARK: - Theme namespace (palette, ink, shadows, motion, radii)

enum Theme {

    // Raw palette straight from the spec hex values.
    enum Palette {
        // Near-white backgrounds (Sherlock — flat, clean)
        static let bgTop      = Color(hex: "#FFFFFE")
        static let bgMid      = Color(hex: "#F8F8F7")
        static let bgBottom   = Color(hex: "#FFFFFE")

        // The one accent — softened dusk indigo/teal (used in both modes)
        static let duskIndigo     = Color(hex: "#2E6C92")
        static let duskIndigoDeep = Color(hex: "#245876")
        static let tealLight      = Color(hex: "#5FA3C2")
        static let coral          = Color(hex: "#FF8A6B")
        // Inky stamp green — the "approved/cleared" mark on the passport.
        static let stampGreen     = Color(hex: "#2E8B57")

        // Ink / text
        static let ink = Color(hex: "#1A1A2E")
    }

    // Semantic ink opacities (Hinge-style soft hierarchy).
    enum Ink {
        static let primary   = Palette.ink
        static let secondary = Palette.ink.opacity(0.62)
        static let tertiary  = Palette.ink.opacity(0.40)
        static let faint     = Palette.ink.opacity(0.18)
        static let hairline  = Palette.ink.opacity(0.08)
    }

    /// The near-white base gradient — flat and clean (Sherlock's diagonal wash).
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Palette.bgTop, Palette.bgMid, Palette.bgBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Shadow ladder — the layered depth that reads as "premium".
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        /// Resting cards, chips.
        static let soft   = ShadowStyle(color: .black.opacity(0.08), radius: 8,  x: 0, y: 3)
        /// Raised surfaces, sheets, active cards.
        static let medium = ShadowStyle(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    // Corner radii.
    enum Radius {
        static let chip: CGFloat   = 26
        static let card: CGFloat   = 20
        static let tile: CGFloat   = 16
        static let button: CGFloat = 16
    }

    // Motion presets (Sherlock spring vocabulary).
    enum Motion {
        /// Snappy press/selection feedback.
        static let snappy  = Animation.spring(response: 0.3, dampingFraction: 0.7)
        /// Gentle reveals and layout shifts.
        static let gentle  = Animation.spring(response: 0.5, dampingFraction: 0.8)
        /// Bouncy, playful (use sparingly).
        static let bouncy  = Animation.spring(response: 0.45, dampingFraction: 0.62)
        /// Apple-Wallet open/close — quick, minimal settle.
        static let wallet  = Animation.spring(response: 0.35, dampingFraction: 0.85)
        /// Page / step transitions.
        static let page    = Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - Shadow convenience

extension View {
    /// Apply one rung of the shadow ladder.
    func themeShadow(_ style: Theme.ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
