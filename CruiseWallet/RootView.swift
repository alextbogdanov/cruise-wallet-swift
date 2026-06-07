//
//  RootView.swift
//  CruiseWallet
//
//  Welcome → Home gate. The Home navigation stack, its shared `@Namespace` for the
//  card→pass morph, and the push destinations now all live inside `HomeView` (the
//  card *is* the hero, so there's no zoom push to coordinate here).
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MockStore

    var body: some View {
        ZStack {
            if store.hasEntered {
                HomeView()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.page, value: store.hasEntered)
    }
}
