//
//  WelcomeView.swift
//  CruiseWallet
//
//  The landing screen. A live `OceanWave` Metal backdrop carries the ocean identity
//  (the chrome itself stays calm); a floating glass logo lockup, a typewriter
//  headline, and the glass CTAs sit over it. "Get started" enters the app.
//
//  Source parity: cruise-wallet/src/app/index.tsx (teal hero, boat mark,
//  "Your Cruise, Your Screen", Get Started) — re-imagined as premium glass + Metal.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: MockStore

    var body: some View {
        ZStack {
            OceanWaveBackground()

            // A gentle vertical scrim so white text stays legible over the brighter
            // top of the swell and the CTAs anchor against the deeper bottom.
            LinearGradient(
                colors: [.black.opacity(0.18), .clear, .black.opacity(0.28)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                logoLockup
                    .entrance(delay: 0.05)

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 14) {
                    TypewriterText(
                        text: "Your cruise,\nin your pocket.",
                        font: .system(size: 40, weight: .bold, design: .serif),
                        color: .white,
                        perCharacter: 0.04,
                        startDelay: 0.35
                    )

                    Text("Every sailing — countdowns, ports, and your ship — as a living boarding pass on your home screen.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .staggeredReveal(index: 0, baseDelay: 1.4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)

                Spacer(minLength: 28)

                VStack(spacing: 12) {
                    PrimaryCTAButton(title: "Get started", icon: "sailboat.fill") {
                        store.hasEntered = true
                    }
                    SecondaryButton(title: "I already have an account", style: .outline) {
                        store.hasEntered = true
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .staggeredReveal(index: 1, baseDelay: 1.6)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var logoLockup: some View {
        VStack(spacing: 16) {
            Image(systemName: "ferry.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                .floating(amplitude: 7, duration: 3.4)

            Text("CRUISE WALLET")
                .font(.system(size: 14, weight: .bold))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}
