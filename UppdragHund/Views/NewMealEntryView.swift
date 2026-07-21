//
//  NewMealEntryView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct NewMealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dog: Dog

    @State private var type: MealType = .meal
    @State private var name = ""
    @State private var time = Date.now
    @State private var note = ""
    @State private var saveError: String?

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Typ", selection: $type) {
                    ForEach(MealType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImage).tag(type)
                    }
                }
                TextField("Namn", text: $name, prompt: Text("t.ex. Monster – Kanin"))
                DatePicker("Tid", selection: $time, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                TextField("Reaktion/anteckning", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle("Logga måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Spara", disabled: !isValid, celebratesSave: true) {
                save()
            }
            .saveErrorAlert($saveError)
        }
    }

    private func save() {
        let entry = MealEntry(
            type: type,
            time: time,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            dog: dog
        )
        modelContext.insert(entry)
        if let message = modelContext.saveOrMessage() {
            saveError = message
            return
        }
        SyncCoordinator.shared.entryTouched(entry, dog: dog)
        ReviewPrompter.registerMeaningfulEvent()
        dismiss()
    }
}

#Preview {
    NewMealEntryView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, MealEntry.self], inMemory: true)
}
