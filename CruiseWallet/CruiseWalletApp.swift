//
//  CruiseWalletApp.swift
//  CruiseWallet
//
//  App entry. Injects the single `MockStore` and shows the root.
//

import SwiftUI

@main
struct CruiseWalletApp: App {
    @StateObject private var store = MockStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.Palette.duskIndigo)
        }
    }
}
