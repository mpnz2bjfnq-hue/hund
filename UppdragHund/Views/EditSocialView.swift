//
//  EditSocialView.swift
//  UppdragHund
//
//  Anpassa Socialt: dra för att ändra ordning, bocka av för att dölja.
//  Speglar EditHomeView så de två anpassningsvyerna ser och beter sig lika.
//

import SwiftUI

struct EditSocialView: View {
    @AppStorage(SocialBlockStore.storageKey) private var blocksRaw = SocialBlockStore.defaultRaw
    @Environment(\.dismiss) private var dismiss

    @State private var ordered: [SocialBlock] = []
    @State private var enabled: Set<SocialBlock> = []

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
                            .accessibilityLabel(block.title)
                            .accessibilityAddTraits(enabled.contains(block) ? [.isSelected] : [])
                        }
                    }
                    .onMove { from, to in
                        ordered.move(fromOffsets: from, toOffset: to)
                    }
                } footer: {
                    Text("Dra i handtagen för att ändra ordning. Bocka av ett block för att dölja det på Socialt.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Anpassa Socialt")
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
        let current = SocialBlockStore.decode(blocksRaw)
        ordered = current + SocialBlock.allCases.filter { !current.contains($0) }
        enabled = Set(current)
    }

    private func toggle(_ block: SocialBlock) {
        if enabled.contains(block) {
            enabled.remove(block)
        } else {
            enabled.insert(block)
        }
    }

    private func save() {
        blocksRaw = SocialBlockStore.encode(ordered.filter { enabled.contains($0) })
        dismiss()
    }
}

#Preview {
    EditSocialView()
}
