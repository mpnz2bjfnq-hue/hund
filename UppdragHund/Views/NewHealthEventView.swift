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
    @State private var injuryBodyView: BodyView = .left
    @State private var injuryPoint: CGPoint?
    @State private var injuryStatus: HealingStatus = .active
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

                }

                if type == .injury {
                    Section("Var sitter skadan?") {
                        DogBodyMap(
                            view: $injuryBodyView,
                            point: $injuryPoint,
                            isEditable: true,
                            markerColor: Theme.Colors.warning
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                    Section("Läkning") {
                        Picker("Status", selection: $injuryStatus) {
                            ForEach(HealingStatus.allCases) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
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
            }
            .bottomActionButton("Spara", disabled: !isValid) {
                save()
            }
        }
    }

    private func save() {
        let event = HealthEvent(
            type: type,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            bodyLocation: nil,
            weightKg: type == .weighing ? parsedWeight : nil,
            temperatureCelsius: type == .temperature ? parsedTemperature : nil,
            dog: dog
        )
        if type == .injury {
            event.injuryView = injuryBodyView
            event.injuryPoint = injuryPoint
            event.injuryStatus = injuryStatus
        }
        modelContext.insert(event)
        SyncCoordinator.shared.entryTouched(event, dog: dog)
        dismiss()
    }
}

#Preview {
    NewHealthEventView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, HealthEvent.self], inMemory: true)
}
