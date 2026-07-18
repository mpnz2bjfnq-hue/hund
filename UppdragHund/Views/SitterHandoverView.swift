//
//  SitterHandoverView.swift
//  UppdragHund
//
//  Hundvaktsläge: ett överlämningskort med allt en hundvakt behöver —
//  hunden, matrutiner, mediciner, kommandon, veterinär och nödkontakt.
//  Redigeras här och delas som formaterad text (Meddelanden/mejl/utskrift).
//

import SwiftUI
import SwiftData

struct SitterHandoverView: View {
    @Bindable var dog: Dog

    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false

    // Aktuella mediciner (loggade de senaste 30 dagarna).
    private var currentMeds: [HealthEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        return dog.healthEvents
            .filter { $0.type == .medication && $0.date >= cutoff }
            .sorted { $0.date > $1.date }
    }

    private var knownCommands: [TrainingSkill] {
        dog.trainingSkills
            .filter { $0.level != .notStarted }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
                dogHeader

                Section("Kontakter") {
                    contactRow(label: "Ägare", name: nil, phone: ownerPhonePlaceholder)
                    contactRow(label: "Veterinär", name: dog.vetName, phone: dog.vetPhone)
                    contactRow(label: "Nödkontakt", name: dog.emergencyContactName, phone: dog.emergencyContactPhone)
                }

                if !currentMeds.isEmpty {
                    Section("Mediciner") {
                        ForEach(currentMeds) { med in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(med.title).font(.subheadline.weight(.medium))
                                if let note = med.note, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if !knownCommands.isEmpty {
                    Section("Kommandon hunden kan") {
                        Text(knownCommands.map(\.name).joined(separator: " · "))
                            .font(.subheadline)
                    }
                }

                Section("Rutiner & att tänka på") {
                    if let notes = dog.careNotes, !notes.isEmpty {
                        Text(notes)
                    } else {
                        Text("Lägg till matschema, rutiner och allergier under Redigera.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        .navigationTitle("Hundvaktsläge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isEditing = true } label: { Label("Redigera", systemImage: "pencil") }
            }
            ToolbarItem(placement: .bottomBar) {
                ShareLink(item: handoverText) {
                    Label("Dela med hundvakt", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            SitterInfoEditView(dog: dog)
        }
    }

    private var dogHeader: some View {
        Section {
            HStack(spacing: Theme.Spacing.l) {
                DogAvatar(photoData: dog.photoData, size: 60, isActive: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dog.name).font(.title3.bold())
                    Text("\(dog.breed) · \(dog.sex.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Född \(dog.birthDate.formatted(date: .abbreviated, time: .omitted)) · \(AgeFormatter.describe(birthDate: dog.birthDate))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ownerPhonePlaceholder: String? { nil }

    @ViewBuilder
    private func contactRow(label: String, name: String?, phone: String?) -> some View {
        if name != nil || phone != nil {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let name { Text(name).font(.subheadline.weight(.medium)) }
                    if let phone {
                        Link(phone, destination: URL(string: "tel:\(phone.filter { !$0.isWhitespace })") ?? URL(string: "tel:0")!)
                            .font(.subheadline)
                    }
                }
            }
        } else if label != "Ägare" {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text("–").foregroundStyle(.tertiary)
            }
        }
    }

    /// Formaterad text för delning/utskrift.
    private var handoverText: String {
        var lines: [String] = []
        lines.append(String(localized: "🐾 Hundvakt-info för \(dog.name)"))
        lines.append("\(dog.breed) · \(dog.sex.displayName) · \(AgeFormatter.describe(birthDate: dog.birthDate))")
        lines.append("")
        if let n = dog.vetName ?? dog.vetPhone {
            _ = n
            lines.append(String(localized: "Veterinär: \(dog.vetName ?? "") \(dog.vetPhone ?? "")"))
        }
        if dog.emergencyContactName != nil || dog.emergencyContactPhone != nil {
            lines.append(String(localized: "Nödkontakt: \(dog.emergencyContactName ?? "") \(dog.emergencyContactPhone ?? "")"))
        }
        if !currentMeds.isEmpty {
            lines.append("")
            lines.append(String(localized: "Mediciner:"))
            for med in currentMeds {
                lines.append("• \(med.title)" + (med.note.map { " – \($0)" } ?? ""))
            }
        }
        if !knownCommands.isEmpty {
            lines.append("")
            lines.append(String(localized: "Kommandon: \(knownCommands.map(\.name).joined(separator: ", "))"))
        }
        if let notes = dog.careNotes, !notes.isEmpty {
            lines.append("")
            lines.append(String(localized: "Rutiner:"))
            lines.append(notes)
        }
        return lines.joined(separator: "\n")
    }
}

/// Redigerar vård-/vaktfälten på hunden.
private struct SitterInfoEditView: View {
    @Bindable var dog: Dog
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Veterinär") {
                    TextField("Namn/klinik", text: Binding($dog.vetName, replacingNilWith: ""))
                    TextField("Telefon", text: Binding($dog.vetPhone, replacingNilWith: ""))
                        .keyboardType(.phonePad)
                }
                Section("Nödkontakt") {
                    TextField("Namn", text: Binding($dog.emergencyContactName, replacingNilWith: ""))
                    TextField("Telefon", text: Binding($dog.emergencyContactPhone, replacingNilWith: ""))
                        .keyboardType(.phonePad)
                }
                Section {
                    TextField("Matschema, rutiner, allergier…", text: Binding($dog.careNotes, replacingNilWith: ""), axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("Rutiner & att tänka på")
                }
            }
            .navigationTitle("Redigera vaktinfo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
    }
}

private extension Binding where Value == String {
    /// Binder ett optional String-fält till ett TextField, tomt = nil.
    init(_ source: Binding<String?>, replacingNilWith empty: String) {
        self.init(
            get: { source.wrappedValue ?? empty },
            set: { source.wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
