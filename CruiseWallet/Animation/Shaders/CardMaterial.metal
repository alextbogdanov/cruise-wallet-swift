//
//  CardMaterial.metal
//  CruiseWallet
//
//  A metallic-foil sheen drawn as a highlight LAYER over a card photo. It's a
//  GPU `.colorEffect` (so it ignores the host pixel and computes its own RGBA)
//  composed of two pieces:
//
//    1. Brushed-metal anisotropic grain — fine, mostly-horizontal banding. The
//       noise varies fast along Y and slowly along X, so it reads as a metal
//       surface that's been brushed left-to-right (the way a foil card catches
//       light differently along vs. across the grain). Low amplitude.
//
//    2. A hot specular streak — a soft bright band whose center is driven by the
//       `light` direction (tilt). As the card tilts the streak sweeps across the
//       surface and its core is warm-white; the falloff is tinted with the app
//       dusk/teal accents. The streak is oriented to follow the grain direction
//       so it smears along the brushing.
//
//  Returns `half4(rgb, a)` with `a` = highlight strength (peaks well under 1) so
//  it composites cleanly over the photo with `.plusLighter`/`.screen`. The grain
//  modulates alpha; the streak adds both alpha and a warm-white push to rgb.
//
//  Genuinely Metal — the per-pixel grain + anisotropic streak math is what gives
//  the foil its living glint; a SwiftUI gradient can't fake the brushed texture.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Cheap hash-noise helpers (no texture sampling needed).
static inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

// Value noise with smooth interpolation.
static inline float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    float2 u = f * f * (3.0 - 2.0 * f);  // smoothstep weights
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

[[ stitchable ]] half4 foilSheen(float2 pos, half4 color, float2 light, float2 size) {
    float2 uv = pos / max(size, float2(1.0, 1.0));   // 0..1 across the view

    // --- App accent tints -------------------------------------------------
    half3 tealLight      = half3(0.373, 0.639, 0.761);   // #5FA3C2
    half3 duskIndigo     = half3(0.180, 0.424, 0.573);   // #2E6C92
    half3 duskIndigoDeep = half3(0.141, 0.345, 0.463);   // #245876
    half3 warmWhite      = half3(1.0, 0.97, 0.92);        // hot specular core

    // --- (a) Brushed-metal anisotropic grain ------------------------------
    // High frequency along Y, low along X => horizontal brushing. Sample a few
    // octaves so the banding has fine structure without looking like scanlines.
    float2 grainUV = float2(uv.x * 6.0, uv.y * 220.0);
    float grain = valueNoise(grainUV);
    grain += valueNoise(grainUV * float2(1.0, 2.3) + 11.0) * 0.5;
    grain += valueNoise(grainUV * float2(2.0, 0.5) + 31.0) * 0.25;
    grain /= 1.75;                       // ~0..1
    grain = grain * 2.0 - 1.0;           // -1..1, signed shimmer
    float grainAmp = 0.06;               // low amplitude — it's a subtle texture

    // --- (b) Hot specular streak ------------------------------------------
    // The streak center tracks the tilt: map light (-1..1) -> 0..1 position.
    float2 lc = clamp(light, float2(-1.0), float2(1.0));
    float2 center = lc * 0.5 + 0.5;      // 0..1 target center across the card

    // Orient the streak to follow the grain (mostly horizontal brushing) so it
    // smears along the brushing. The streak is a band in a "sweep coordinate"
    // that's dominated by the vertical axis but skewed by the tilt direction.
    // Distance from the moving center, weighted so the band runs along X.
    float2 d = uv - center;
    // Anisotropic distance: tight across the grain (Y), loose along it (X).
    float across = d.y;                  // perpendicular to brushing
    float along  = d.x;                  // parallel to brushing
    // Skew the band slightly toward the tilt vector so it leans as you turn.
    across += along * lc.x * 0.20;

    float streakDist = abs(across);
    // Soft bright band: bright at the center line, fading out within ~0.22 uv.
    float streak = smoothstep(0.28, 0.0, streakDist);
    streak = pow(streak, 1.6);           // tighten the core
    // Fade the streak toward the long edges so it reads as a contained glint.
    float alongFade = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
    streak *= mix(0.65, 1.0, alongFade);

    // A second, broader sheen wash that follows the same center for depth.
    float wash = smoothstep(0.7, 0.0, streakDist) * 0.35;

    // --- Combine into a highlight value -----------------------------------
    // Grain rides on top of the streak so the brushing only really shows where
    // light is catching the surface (plus a faint everywhere base).
    float grainMod = grainAmp * (0.35 + 0.65 * (streak + wash));
    float highlight = streak * 0.9 + wash + grain * (grainMod / grainAmp) * grainAmp;
    highlight = clamp(highlight, 0.0, 1.0);

    // --- Tint the highlight ------------------------------------------------
    // Hottest part -> warm white; mid -> tealLight; cool falloff -> dusk hues.
    half3 tint = mix(duskIndigoDeep, duskIndigo, half(smoothstep(0.0, 0.4, highlight)));
    tint = mix(tint, tealLight, half(smoothstep(0.25, 0.65, highlight)));
    tint = mix(tint, warmWhite, half(smoothstep(0.6, 1.0, streak)));  // core only

    // --- Alpha: highlight strength, peaks well below 1 --------------------
    float alpha = highlight * 0.5;       // cap ~0.5 so the photo stays dominant

    // Premultiply-ish: scale rgb by alpha so plusLighter/screen reads cleanly.
    return half4(tint * half(alpha), half(alpha));
}
