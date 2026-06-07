//
//  Transitions.swift
//  Cruzero
//
//  Shared motion vocabulary for the app's screen-to-screen flow and hero art.
//  Sherlock leaned on Lottie + alpha `.mov` loops for motion; in this mockup the
//  generated assets are static PNGs, so we get the "alive" premium feel from
//  SwiftUI-native primitives instead:
//
//   • `revealForward` / `revealBack` — directional page transitions for the
//     welcome → explainers → auth coordinator (asymmetric: new content slides in,
//     old content just fades, so the eye follows the incoming screen).
//   • `.entrance(...)` — a one-shot spring "pop + rise + fade-in" applied to hero
//     art and titles as a screen appears, optionally staggered by `delay`.
//   • `.floating(...)` — a gentle, never-ending vertical bob that keeps hero
//     images from feeling like dead stickers.
//
//  Every effect honors `accessibilityReduceMotion`: reveals collapse to a plain
//  opacity fade, the entrance snaps straight to its resting state, and the float
//  is disabled entirely.
//

import SwiftUI
import UIKit

// MARK: - Haptics (beat-by-beat reveal feedback)

/// Lightweight wrappers around `UIImpactFeedbackGenerator` so the choreographed
/// reveals can punctuate each beat with a physical tap — the same trick Sherlock
/// uses to make a cascade *feel* sequenced, not just look it. No-ops are cheap,
/// so callers fire freely; everything is skipped under Reduce Motion at the call
/// site (the staggered reveal never schedules a tap when motion is reduced).
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// Fire a light tap after `delay` seconds — used to sync a haptic with the
    /// spring that reveals a staggered element.
    static func impactAfter(_ delay: Double, style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { impact(style) }
    }

    /// A success "notification" tap — the heftier, three-pulse confirmation used
    /// for completion moments (e.g. the passport being issued).
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Directional page transitions

extension AnyTransition {
    /// Moving *forward* through the flow (Continue / Next): the incoming screen
    /// slides in from the trailing edge while the outgoing one dissolves.
    static var revealForward: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Moving *back* (Back / dismiss): mirror of `revealForward`.
    static var revealBack: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// A "moment" transition for milestone/hero screens (the chapter breaks, the
    /// permission asks, the finish): the incoming screen *blooms* — it rises a
    /// touch, scales up from slightly small, and fades in, while the outgoing one
    /// settles back and dissolves. Direction-agnostic on purpose: a break is a
    /// pause in the left→right question rhythm, not another step in it. Pairing
    /// this with the horizontal `reveal*` slides gives the flow two clearly
    /// different motion languages — sideways = answering, bloom = a beat.
    static var bloom: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9)
                .combined(with: .opacity)
                .combined(with: .offset(y: 30)),
            removal: .scale(scale: 1.03).combined(with: .opacity)
        )
    }

    /// The default for *question* steps, replacing the old horizontal `reveal*`
    /// slide that read as monotone. Incoming content rises ~16pt, scales up from
    /// 0.98, and fades; the outgoing step simply dissolves. Only the rise sign
    /// encodes direction (forward rises *up* into place, back drops *down*), so
    /// the motion stays vertical and calm — a soft re-settle rather than a
    /// conveyor belt. Pair with `bloom` (kept for milestones) for two distinct
    /// motion languages: soft-fade = answering, bloom = a beat.
    static var softFadeForward: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 16).combined(with: .scale(scale: 0.98)).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Mirror of `softFadeForward` for backward navigation: incoming drops in
    /// from slightly above instead of rising from below.
    static var softFadeBack: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -16).combined(with: .scale(scale: 0.98)).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// The rules clipboard's hand-off transition. It *enters* with the same gentle
    /// bloom as the other milestone screens (so backing into it from the passport
    /// is unchanged), but on the way *out* it's **tossed up** off the top of the
    /// screen — a brisk, decelerating throw that shrinks and tilts the board a hair
    /// as it flies clear (see `ClipboardTossModifier`). The throw is timed so the
    /// board clears the top just as the passport launches up from the bottom (its
    /// own ~0.4s `playIntro` eject), so the two screens read as a single continuous
    /// upward gesture rather than two separate changes. The removal carries its own
    /// `.animation` so the toss keeps its throw curve regardless of the container's
    /// ambient transition animation. Used only for `.rules`; under Reduce Motion the
    /// flow falls back to a plain cross-dissolve at the call site.
    static var clipboardToss: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9)
                .combined(with: .opacity)
                .combined(with: .offset(y: 30)),
            removal: AnyTransition
                .modifier(active: ClipboardTossModifier(progress: 1),
                          identity: ClipboardTossModifier(progress: 0))
                // Brisk launch easing out — a thrown object, not a slow fade. Lasts
                // just past the passport's 0.4s launch delay so the board is still
                // clearing the top as the passport surges up from the bottom.
                .animation(.timingCurve(0.2, 0.7, 0.35, 1.0, duration: 0.55))
        )
    }
}

/// Renders the rules clipboard being *tossed up* and off the top of the screen.
/// `progress` runs 0 (resting, on screen) → 1 (thrown clear, well above the top
/// edge): the board flings straight up, receding and tilting a touch as it goes,
/// then fades the last of itself so nothing pops as the view is removed. Kept
/// essentially vertical (small tilt, no sideways drift) so the motion lines up
/// with the passport's straight-up launch for a clean hand-off.
private struct ClipboardTossModifier: ViewModifier {
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            // Recede as it's thrown up and away.
            .scaleEffect(1 - 0.16 * progress, anchor: .center)
            // A slight tumble off the wrist — small, so the throw stays vertical.
            .rotationEffect(.degrees(-5 * progress), anchor: .center)
            // The fling: well past the top edge so the whole clipboard clears.
            .offset(y: -1100 * progress)
            // Hold opacity while it's still on screen, then fade the tail so the
            // removal never pops.
            .opacity(progress < 0.7 ? 1 : Double(1 - (progress - 0.7) / 0.3))
    }
}

// MARK: - Entrance (one-shot spring reveal on appear)

private struct EntranceModifier: ViewModifier {
    var delay: Double
    var yOffset: CGFloat
    var startScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : startScale)
            .offset(y: shown ? 0 : yOffset)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(Theme.Motion.gentle.delay(delay)) { shown = true }
                }
            }
    }
}

extension View {
    /// Spring "pop + rise + fade-in" as the view appears. Stagger sibling
    /// elements (title, hero, buttons) with increasing `delay` for a cascade.
    func entrance(delay: Double = 0, yOffset: CGFloat = 18, startScale: CGFloat = 0.96) -> some View {
        modifier(EntranceModifier(delay: delay, yOffset: yOffset, startScale: startScale))
    }
}

// MARK: - Floating (continuous gentle bob)

private struct FloatingModifier: ViewModifier {
    var amplitude: CGFloat
    var duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amplitude : amplitude)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

extension View {
    /// A slow vertical drift that keeps hero art feeling buoyant — like it's
    /// riding a swell. Disabled under Reduce Motion.
    func floating(amplitude: CGFloat = 7, duration: Double = 3.2) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, duration: duration))
    }
}

// MARK: - Staggered reveal (sequenced cascade with haptics)

/// A position-aware sibling of `.entrance`: instead of every element guessing
/// its own `delay`, each gets an `index` and the modifier derives the delay
/// (`baseDelay + index * step`) so a column of rows cascades in beat by beat.
/// Each beat also fires a light haptic synced to its spring — Sherlock's
/// dropdown-cascade trick that makes a reveal *feel* sequenced. Under Reduce
/// Motion the whole stack snaps in at once and no haptics fire.
private struct StaggeredRevealModifier: ViewModifier {
    let index: Int
    var baseDelay: Double
    var step: Double
    var yOffset: CGFloat
    var xOffset: CGFloat
    var haptic: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : xOffset, y: shown ? 0 : yOffset)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                let delay = baseDelay + Double(index) * step
                withAnimation(Theme.Motion.gentle.delay(delay)) { shown = true }
                if haptic { Haptics.impactAfter(delay) }
            }
    }
}

extension View {
    /// Reveal this element as part of a sequenced cascade. Give each sibling an
    /// increasing `index`; the delay (and an optional synced haptic) follow from
    /// it. `xOffset` lets rows slide in from the trailing edge (Sherlock's
    /// notification cascade); leave it 0 for a pure rise.
    func staggeredReveal(
        index: Int,
        baseDelay: Double = 0.08,
        step: Double = 0.07,
        yOffset: CGFloat = 14,
        xOffset: CGFloat = 0,
        haptic: Bool = true
    ) -> some View {
        modifier(StaggeredRevealModifier(
            index: index, baseDelay: baseDelay, step: step,
            yOffset: yOffset, xOffset: xOffset, haptic: haptic
        ))
    }
}

// MARK: - Paper reveals (clipboard "filled out" motion)
//
// A motion vocabulary for surfaces that read as *physical paper* (the rules
// clipboard), where the generic card gestures — slide-in, scale-pop — break the
// illusion. Here a sheet is *set down* and marks *ink on in place*: nothing
// translates sideways, nothing pops up from small. All three honor
// `accessibilityReduceMotion` by snapping to rest and firing no haptics.

/// An object being *set down*: it drops in from slightly above with a hair of
/// rotation, settling flat with a small overshoot (`Theme.Motion.bouncy`) so it
/// reads as a physical thing placed on a surface — the clipboard landing — not a
/// UI card popping into existence. One-shot. The transforms are render-only
/// (offset/rotation/scale via `withAnimation`), so this is safe to wrap a view
/// that contains a `GeometryReader`: we move the parent, never its frame.
private struct DropInModifier: ViewModifier {
    var yFrom: CGFloat
    var rotationFrom: Double
    var animation: Animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .rotationEffect(.degrees(shown ? 0 : rotationFrom))
            .offset(y: shown ? 0 : yFrom)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(animation) { shown = true }
            }
    }
}

extension View {
    /// Drop this view in from slightly above with a settle, like an object set down
    /// on a surface. Reserved for whole "physical" panels (the rules clipboard) —
    /// not a card-pop substitute. Pass a slower `animation` for a more deliberate
    /// landing.
    func dropIn(yFrom: CGFloat = -28, rotationFrom: Double = -2.5,
                animation: Animation = Theme.Motion.bouncy) -> some View {
        modifier(DropInModifier(yFrom: yFrom, rotationFrom: rotationFrom, animation: animation))
    }
}

/// Ink fading onto paper: `opacity 0→1` plus a tiny rise that settles to rest —
/// *no* horizontal slide and *no* scale. Printed letterhead and handwriting
/// appear where they sit, the way a mark lands on a page. One-shot, `delay`-based
/// so a caller can sequence siblings with `base + index * step`.
private struct InkInModifier: ViewModifier {
    var delay: Double
    var rise: CGFloat
    var animation: Animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : rise)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(animation.delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// Fade a printed/written mark onto paper in place (opacity + a small settle
    /// rise, no slide, no scale). The paper-native replacement for `.entrance()`.
    /// Pass a slower `animation` for a calmer, more deliberate fade.
    func inkIn(delay: Double = 0, rise: CGFloat = 4,
               animation: Animation = Theme.Motion.gentle) -> some View {
        modifier(InkInModifier(delay: delay, rise: rise, animation: animation))
    }
}

/// A check-mark *stamping* onto the sheet: it lands slightly oversized and snaps
/// to rest (`scale 1.28→1`) with a fade, punctuated by a light tap — like a pen
/// ticking a box. Adds only scale+fade, so it composes cleanly over a static
/// resting tilt applied by the caller. One-shot, `delay`-based; the synced haptic
/// reuses `Haptics.impactAfter`.
private struct StampInModifier: ViewModifier {
    var delay: Double
    var haptic: Bool
    var from: CGFloat
    var animation: Animation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : from)
            .onAppear {
                guard !shown else { return }
                if reduceMotion { shown = true; return }
                withAnimation(animation.delay(delay)) { shown = true }
                if haptic { Haptics.impactAfter(delay) }
            }
    }
}

extension View {
    /// Stamp this glyph in — a scale-to-rest with a synced light tap, like ticking
    /// a checkbox by hand. Pairs with `inkIn` for the text. `from` sets the starting
    /// scale: large (1.28) for a pronounced pop, near 1 for a calm settle. Pass an
    /// `animation` with higher damping to land without wobble.
    func stampIn(delay: Double = 0, haptic: Bool = true, from: CGFloat = 1.28,
                 animation: Animation = Theme.Motion.snappy) -> some View {
        modifier(StampInModifier(delay: delay, haptic: haptic, from: from, animation: animation))
    }
}

// MARK: - Parallax float (entrance + continuous drift for hero art)

/// A richer replacement for `.floating()` on full-bleed hero illustrations: the
/// image *settles* in (scales up from slightly small + fades) and then keeps a
/// slow vertical drift, so the art arrives with intent and never sits dead.
/// Under Reduce Motion it snaps to its resting frame with no drift.
private struct ParallaxFloatModifier: ViewModifier {
    var amplitude: CGFloat
    var duration: Double
    var settleScale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var drift = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1 : settleScale)
            .opacity(appeared ? 1 : 0)
            .offset(y: drift ? -amplitude : amplitude)
            .onAppear {
                if reduceMotion { appeared = true; return }
                withAnimation(Theme.Motion.gentle) { appeared = true }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
    }
}

extension View {
    /// Entrance settle + continuous buoyant drift for hero art — the premium
    /// "alive at rest" treatment for full-bleed illustrations.
    func parallaxFloat(amplitude: CGFloat = 8, duration: Double = 3.6, settleScale: CGFloat = 0.94) -> some View {
        modifier(ParallaxFloatModifier(amplitude: amplitude, duration: duration, settleScale: settleScale))
    }
}

// MARK: - Foil shimmer (gold-leaf sheen on stamps & seals)

/// A tasteful "foil" sheen: a soft warm-white highlight band sweeps diagonally
/// across a view's inked pixels, pauses, then sweeps again — like light catching
/// gold leaf on an embossed stamp. It's the one onboarding accent that isn't a
/// spring or a drift, reserved for the "official document" emblems (the rules
/// seal, the explainer bullet icons).
///
/// **Implementation note — why SwiftUI, not Metal.** Phase 4 was specced as a
/// `[[ stitchable ]]` Metal `colorEffect`, with this pure-SwiftUI sweep as the
/// documented fallback "if Metal integration fights the build." It does: this
/// machine's Xcode has no Metal toolchain installed (`.metal` compiles fail with
/// *"missing Metal Toolchain"*), so we take the fallback — visually equivalent,
/// zero shader pipeline. The look is built from the classic shimmer recipe: a
/// moving gradient band, `.mask(content)` to confine the sheen to the glyph's
/// silhouette (not its bounding box), and `.plusLighter` so the band *brightens*
/// the ink rather than painting over it.
///
/// The sweep is driven by a `TimelineView` clock so we can park the band
/// off-screen for most of the period (one quick pass, then a rest) — constant
/// motion would read as gaudy. Under Reduce Motion we render the plain content
/// and install neither the overlay nor the clock, so there's zero ongoing work.
private struct FoilShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds per full cycle, and the fraction of it the band is actually
    /// crossing (the rest is a rest — band parked off-screen).
    private let period: Double = 3.4
    private let sweepWindow: Double = 0.34

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.overlay {
                TimelineView(.animation) { timeline in
                    sheen(progress: progress(at: timeline.date))
                }
                .mask(content)
                .allowsHitTesting(false)
            }
        }
    }

    /// Map wall-clock time to a 0→1 sweep position during the window, then park
    /// the band well past the trailing edge (>1) for the remainder of the cycle.
    private func progress(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        return phase < sweepWindow ? CGFloat(phase / sweepWindow) : 1.6
    }

    /// A narrow, slightly-tilted warm-white band offset across the view's width.
    /// Masked to the glyph by the caller and blended additively so it reads as a
    /// glint of light, not a painted stripe.
    private func sheen(progress: CGFloat) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let bandW = max(w * 0.55, 16)
            let x = -bandW + progress * (w + bandW)
            LinearGradient(
                colors: [
                    .clear,
                    Color(red: 1.0, green: 0.97, blue: 0.9).opacity(0.6),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: bandW)
            .rotationEffect(.degrees(18))
            .offset(x: x)
            .frame(width: w, height: geo.size.height, alignment: .leading)
            .blendMode(.plusLighter)
        }
    }
}

extension View {
    /// A tasteful "foil" sheen: a soft diagonal highlight sweeps across the
    /// view's inked pixels every few seconds, like light catching gold leaf on a
    /// stamp. Best on small, high-contrast emblems (seals, stamp glyphs, bullet
    /// icons). Fully disabled under Reduce Motion. See `FoilShimmerModifier` for
    /// why this is SwiftUI rather than the originally-specced Metal shader.
    func foilShimmer() -> some View {
        modifier(FoilShimmerModifier())
    }
}
