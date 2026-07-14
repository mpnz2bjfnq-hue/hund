//
//  AddDogView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct AddDogView: View {
    private static let otherOption = "Annan"

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let dogToEdit: Dog?
    private let knownBreedNames: [String]

    @State private var name: String
    @State private var selectedBreed: String
    @State private var customBreedText: String
    @State private var birthDate: Date
    @State private var sex: DogSex

    init(dogToEdit: Dog? = nil) {
        self.dogToEdit = dogToEdit

        let breeds = BreedDataService.shared.references
            .map(\.breedName)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        self.knownBreedNames = breeds

        let existingBreed = dogToEdit?.breed ?? ""
        if existingBreed.isEmpty {
            _selectedBreed = State(initialValue: breeds.first ?? Self.otherOption)
            _customBreedText = State(initialValue: "")
        } else if breeds.contains(existingBreed) {
            _selectedBreed = State(initialValue: existingBreed)
            _customBreedText = State(initialValue: "")
        } else {
            _selectedBreed = State(initialValue: Self.otherOption)
            _customBreedText = State(initialValue: existingBreed)
        }

        _name = State(initialValue: dogToEdit?.name ?? "")
        _birthDate = State(initialValue: dogToEdit?.birthDate ?? .now)
        _sex = State(initialValue: dogToEdit?.sex ?? .female)
    }

    private var isCustomBreed: Bool {
        selectedBreed == Self.otherOption
    }

    private var resolvedBreed: String {
        isCustomBreed ? customBreedText.trimmingCharacters(in: .whitespacesAndNewlines) : selectedBreed
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !resolvedBreed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Om hunden") {
                    TextField("Namn", text: $name)

                    Picker("Ras", selection: $selectedBreed) {
                        ForEach(knownBreedNames, id: \.self) { breedName in
                            Text(breedName).tag(breedName)
                        }
                        Text(Self.otherOption).tag(Self.otherOption)
                    }

                    if isCustomBreed {
                        TextField("Ange ras", text: $customBreedText)
                    }

                    DatePicker("Född", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    Picker("Kön", selection: $sex) {
                        ForEach(DogSex.allCases) { sex in
                            Text(sex.displayName).tag(sex)
                        }
                    }
                }
            }
            .navigationTitle(dogToEdit == nil ? "Lägg till hund" : "Redigera hund")
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if let dogToEdit {
            dogToEdit.name = trimmedName
            dogToEdit.breed = resolvedBreed
            dogToEdit.birthDate = birthDate
            dogToEdit.sex = sex
            SyncCoordinator.shared.dogProfileTouched(dogToEdit)
        } else {
            let dog = Dog(
                name: trimmedName,
                breed: resolvedBreed,
                birthDate: birthDate,
                sex: sex
            )
            modelContext.insert(dog)
        }
        dismiss()
    }
}

#Preview {
    AddDogView()
        .modelContainer(for: Dog.self, inMemory: true)
}
