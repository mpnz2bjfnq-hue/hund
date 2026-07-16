//
//  EditShortcutsView.swift
//  UppdragHund
//
//  Ark för att välja vilka genvägar som visas på Hem – lägga till eller ta bort.
//

import SwiftUI

struct EditShortcutsView: View {
    @AppStorage(HomeShortcutStore.storageKey) private var shortcutsRaw = HomeShortcutStore.defaultRaw
    @Environment(\.dismiss) private var dismiss

    private var selected: [HomeShortcut] { HomeShortcutStore.decode(shortcutsRaw) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(HomeShortcut.allCases) { shortcut in
                        Button {
                            toggle(shortcut)
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                Image(systemName: shortcut.icon)
                                    .foregroundStyle(Theme.Colors.brand)
                                    .frame(width: 28)
                                Text(shortcut.title)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                if selected.contains(shortcut) {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Theme.Colors.brand)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Valda genvägar visas på Hem. Tryck för att lägga till eller ta bort.")
                }
            }
            .navigationTitle("Ändra genvägar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ shortcut: HomeShortcut) {
        var list = selected
        if let index = list.firstIndex(of: shortcut) {
            list.remove(at: index)
        } else {
            list.append(shortcut)
        }
        shortcutsRaw = HomeShortcutStore.encode(list)
    }
}

#Preview {
    EditShortcutsView()
}
