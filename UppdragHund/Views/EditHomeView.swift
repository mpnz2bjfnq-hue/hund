//
//  EditHomeView.swift
//  UppdragHund
//
//  Anpassa hemskärmen: dra blocken i den ordning du vill och bocka av/på
//  vilka som visas.
//

import SwiftUI

struct EditHomeView: View {
    @AppStorage(HomeBlockStore.storageKey) private var blocksRaw = HomeBlockStore.defaultRaw
    @Environment(\.dismiss) private var dismiss

    @State private var ordered: [HomeBlock] = []
    @State private var enabled: Set<HomeBlock> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordered) { block in
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: block.icon)
                                .foregroundStyle(Theme.Colors.brand)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(block.title)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text(block.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            Button {
                                toggle(block)
                            } label: {
                                Image(systemName: enabled.contains(block) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(enabled.contains(block) ? Theme.Colors.brand : Theme.Colors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onMove { from, to in
                        ordered.move(fromOffsets: from, toOffset: to)
                    }
                } footer: {
                    Text("Dra i handtagen för att ändra ordning. Bocka av ett block för att dölja det på Hem.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Anpassa hem")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { save() }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        let current = HomeBlockStore.decode(blocksRaw)
        ordered = current + HomeBlock.allCases.filter { !current.contains($0) }
        enabled = Set(current)
    }

    private func toggle(_ block: HomeBlock) {
        if enabled.contains(block) {
            enabled.remove(block)
        } else {
            enabled.insert(block)
        }
    }

    private func save() {
        blocksRaw = HomeBlockStore.encode(ordered.filter { enabled.contains($0) })
        dismiss()
    }
}

#Preview {
    EditHomeView()
}
