//
//  OceanWaveBackground.swift
//  CruiseWallet
//
//  SwiftUI host for the `oceanWave` Metal `colorEffect`. A `TimelineView(.animation)`
//  feeds a wall-clock `time` uniform so the swell drifts continuously on the GPU; a
//  `GeometryReader` supplies the view size in points. Under Reduce Motion the clock
//  is frozen (a still, calm ocean) so there's no ongoing work.
//
//  The shader paints its own full color, so the base `Rectangle` fill is irrelevant —
//  it's just a canvas for `.colorEffect`.
//

import SwiftUI

struct OceanWaveBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Rectangle()
                    .fill(.black)
                    .colorEffect(
                        ShaderLibrary.oceanWave(
                            .float(t),
                            .float2(Float(size.width), Float(size.height))
                        )
                    )
            }
        }
        .ignoresSafeArea()
    }
}
