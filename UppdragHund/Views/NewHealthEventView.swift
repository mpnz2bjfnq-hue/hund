//
//  NewHealthEventView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct NewHealthEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dog: Dog

    @State private var type: HealthEventType
    @State private var title: String
    @State private var date = Date.now
    @State private var note = ""
    @State private var bodyLocation: BodyLocation = .frontLeftLeg
    @State private var weightText = ""
    @State private var temperatureText = ""

    init(dog: Dog, initialType: HealthEventType = .vetVisit) {
        self.dog = dog
        _type = State(initialValue: initialType)
        _title = State(initialValue: initialType == .vetVisit ? "" : initialType.displayName)
    }

    private var parsedWeight: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedTemperature: Double? {
        Double(temperatureText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch type {
        case .weighing: return parsedWeight != nil
        case .temperature: return parsedTemperature != nil
        default: return true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Typ") {
                    Picker("Typ", selection: $type) {
                        ForEach(HealthEventType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage).tag(type)
                        }
                    }
                }

                Section {
                    TextField("Titel", text: $title, prompt: Text("t.ex. Årskontroll"))
                    DatePicker("Datum", selection: $date, in: ...Date.now, displayedComponents: .date)

                    if type == .weighing {
                        TextField("Vikt (kg)", text: $weightText)
                            .keyboardType(.decimalPad)
                    }

                    if type == .temperature {
                        TextField("Temperatur (°C)", text: $temperatureText)
                            .keyboardType(.decimalPad)
                    }

                    if type == .injury {
                        Picker("Kroppsplats", selection: $bodyLocation) {
                            ForEach(BodyLocation.allCases) { location in
                                Text(location.displayName).tag(location)
                            }
                        }
                    }
                }

                Section("Anteckning") {
                    TextField("Valfritt...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Ny loggpost")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let event = HealthEvent(
            type: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            bodyLocation: type == .injury ? bodyLocation : nil,
            weightKg: type == .weighing ? parsedWeight : nil,
            temperatureCelsius: type == .temperature ? parsedTemperature : nil,
            dog: dog
        )
        modelContext.insert(event)
        SyncCoordinator.shared.entryTouched(event, dog: dog)
        dismiss()
    }
}

#Preview {
    NewHealthEventView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, HealthEvent.self], inMemory: true)
}
