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
    @State private var injuryBodyView: BodyView = .side
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

    /// Vad tröskeln jämförs mot: hundens normaltemp om satt, annars riktvärdet.
    private var referenceText: String {
        dog.normalTemperatureCelsius != nil ? "\(dog.name)s normaltemp" : "riktvärdet"
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
                    .onChange(of: type) { _, newType in
                        // Fyll rubriken automatiskt med typens namn (t.ex.
                        // Vägning, Temperatur); veterinärbesök namnger man själv.
                        title = newType == .vetVisit ? "" : newType.displayName
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
                        if let temp = parsedTemperature, dog.isTemperatureElevated(temp) {
                            Label {
                                Text("Förhöjd temp – över \(referenceText) (\(String(format: "%.1f", dog.elevatedTemperatureThreshold)) °C)")
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.warning)
                        }
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
        try? modelContext.save()
        SyncCoordinator.shared.entryTouched(event, dog: dog)
        dismiss()
    }
}

#Preview {
    NewHealthEventView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, HealthEvent.self], inMemory: true)
}
