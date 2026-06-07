//
//  OceanWave.metal
//  CruiseWallet
//
//  A calm, slowly drifting ocean wash for the Welcome backdrop. Layered sine
//  "swells" modulate a vertical dusk gradient (the app accent hues), with a soft
//  diagonal light sweep that reads as sun catching the water. It's a GPU
//  `colorEffect`: it ignores the host pixel and computes its own color from the
//  fragment position, a `time` uniform (seconds, driven by a TimelineView clock),
//  and the view's point `size`. Honors Reduce Motion at the call site by freezing
//  `time`.
//
//  Genuinely Metal (not a SwiftUI gradient fake): the per-pixel swell + sweep math
//  is what gives the surface its living, refractive feel under the glass lockup.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 oceanWave(float2 pos, half4 color, float time, float2 size) {
    float2 uv = pos / max(size, float2(1.0, 1.0));   // 0..1 across the view

    // Vertical dusk gradient: lighter sky-water at top, deep accent at the bottom.
    half3 light = half3(0.373, 0.639, 0.761);   // #5FA3C2  (tealLight)
    half3 mid   = half3(0.180, 0.424, 0.573);   // #2E6C92  (duskIndigo)
    half3 deep  = half3(0.141, 0.345, 0.463);   // #245876  (duskIndigoDeep)

    half3 base = mix(light, deep, half(uv.y));
    // Pull the midtone through the middle band for a richer falloff.
    half midMix = half(0.5 - 0.5 * cos(uv.y * 3.14159265));
    base = mix(base, mid, midMix * half(0.6));

    // Layered swells — three sine bands at different scales/speeds.
    float w = 0.0;
    w += sin(uv.x * 6.2831853 * 1.0 + time * 0.55) * 0.50;
    w += sin(uv.x * 6.2831853 * 2.0 - time * 0.85 + uv.y * 4.0) * 0.25;
    w += sin(uv.x * 6.2831853 * 0.5 + time * 0.30 + uv.y * 2.0) * 0.25;
    float swell = w * 0.5 + 0.5;                 // 0..1

    // Confine the brightening toward the lower water, fading out near the top.
    float band = smoothstep(0.15, 0.95, uv.y);
    half3 crest = base + half3(0.05, 0.06, 0.07) * half(swell * band);

    // A slow diagonal light sweep — sun glance moving across the swell.
    float sweep = sin((uv.x + uv.y) * 3.0 - time * 0.4);
    crest += half3(0.05) * half(max(0.0, sweep) * band);

    return half4(crest, 1.0);
}
