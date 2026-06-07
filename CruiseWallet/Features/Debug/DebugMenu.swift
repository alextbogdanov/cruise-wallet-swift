//
//  DebugMenu.swift
//  CruiseWallet
//
//  A tiny mockup utility (cruzero's DebugMenuView pattern): jump back to Welcome,
//  reset the sample data. The three statuses (before/during/after) are always
//  present across the sample sailings, so every countdown + chart state is visible
//  without toggling.
//

import SwiftUI

struct DebugMenu: View {
    @EnvironmentObject private var store: MockStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Flow") {
                    Button {
                        store.hasEntered = false
                        dismiss()
                    } label: {
                        Label("Return to Welcome", systemImage: "arrow.uturn.backward")
                    }
                }
                Section("Data") {
                    Button {
                        store.reset()
                        dismiss()
                    } label: {
                        Label("Reset sailings", systemImage: "arrow.clockwise")
                    }
                }
                Section("Sailings") {
                    ForEach(store.sailings) { s in
                        HStack {
                            Text(s.shipName)
                            Spacer()
                            Text(store.status(for: s).chip.text)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(store.status(for: s).chip.color)
                        }
                    }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
