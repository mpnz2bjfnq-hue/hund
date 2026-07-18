//
//  NewTrainingSessionView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct NewTrainingSessionView: View {
    private static let otherOption = "Annan"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dog: Dog

    @State private var date = Date.now
    @State private var selectedActivity = TrainingActivityType.recall.displayName
    @State private var customActivityText = ""
    @State private var durationText = ""
    @State private var distanceText = ""
    @State private var note = ""

    private var isCustomActivity: Bool {
        selectedActivity == Self.otherOption
    }

    private var resolvedActivity: String {
        isCustomActivity ? customActivityText.trimmingCharacters(in: .whitespacesAndNewlines) : selectedActivity
    }

    private var parsedDuration: Int? {
        Int(durationText)
    }

    private var parsedDistance: Double? {
        guard let value = Double(distanceText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    private var isValid: Bool {
        !resolvedActivity.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Aktivitet", selection: $selectedActivity) {
                    ForEach(TrainingActivityType.allCases) { type in
                        Text(type.displayName).tag(type.displayName)
                    }
                    Text(Self.otherOption).tag(Self.otherOption)
                }

                if isCustomActivity {
                    TextField("Ange aktivitet", text: $customActivityText)
                }

                DatePicker("Datum", selection: $date, in: ...Date.now, displayedComponents: .date)
                TextField("Längd (minuter)", text: $durationText)
                    .keyboardType(.numberPad)
                TextField("Sträcka (meter)", text: $distanceText)
                    .keyboardType(.numberPad)
                TextField("Anteckning", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            .navigationTitle("Logga träning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Spara", disabled: !isValid) {
                save()
            }
        }
    }

    private func save() {
        let session = TrainingSession(
            date: date,
            activity: resolvedActivity,
            durationMinutes: parsedDuration,
            distanceMeters: parsedDistance,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            dog: dog
        )
        modelContext.insert(session)
        try? modelContext.save()
        SyncCoordinator.shared.entryTouched(session, dog: dog)
        dismiss()
    }
}

#Preview {
    NewTrainingSessionView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, TrainingSession.self], inMemory: true)
}
