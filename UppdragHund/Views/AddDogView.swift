//
//  AddDogView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var cropCandidate: CropCandidate?
    @State private var color: String
    @State private var registrationNumber: String
    @State private var chipNumber: String
    @State private var breeder: String
    @State private var normalTempText: String

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
        _photoData = State(initialValue: dogToEdit?.photoData)
        _color = State(initialValue: dogToEdit?.color ?? "")
        _registrationNumber = State(initialValue: dogToEdit?.registrationNumber ?? "")
        _chipNumber = State(initialValue: dogToEdit?.chipNumber ?? "")
        _breeder = State(initialValue: dogToEdit?.breeder ?? "")
        _normalTempText = State(initialValue: dogToEdit?.normalTemperatureCelsius.map { String(format: "%.1f", $0) } ?? "")
        _isDeceased = State(initialValue: dogToEdit?.passedAwayDate != nil)
        _passedAwayDate = State(initialValue: dogToEdit?.passedAwayDate ?? .now)
    }

    @State private var isDeceased: Bool = false
    @State private var passedAwayDate: Date = .now

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
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            DogAvatar(photoData: photoData, size: 96)
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text(photoData == nil ? "Lägg till bild" : "Byt bild")
                            }
                            if photoData != nil {
                                Button("Justera bild") {
                                    if let data = photoData, let image = UIImage(data: data) {
                                        cropCandidate = CropCandidate(image: image)
                                    }
                                }
                                .font(.caption)
                                Button("Ta bort bild", role: .destructive) {
                                    photoData = nil
                                    photoItem = nil
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

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

                Section("Registrering (valfritt)") {
                    TextField("Färg", text: $color)
                    TextField("Registreringsnummer", text: $registrationNumber)
                        .autocorrectionDisabled()
                    TextField("Chipnummer", text: $chipNumber)
                        .keyboardType(.numberPad)
                    TextField("Uppfödare", text: $breeder)
                }

                Section {
                    TextField("Normaltemp (°C)", text: $normalTempText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Hälsa (valfritt)")
                } footer: {
                    Text("Hundars normaltemp ligger oftast på 38–39 °C. Anger du den flaggar hälsologgen en temp som är över den.")
                }

                Section {
                    Toggle("Hunden har gått bort", isOn: $isDeceased.animation())
                        if isDeceased {
                            DatePicker(
                                "Datum",
                                selection: $passedAwayDate,
                                in: birthDate...Date.now,
                                displayedComponents: .date
                            )
                        }
                } header: {
                    Text("Till minne 🌈")
                } footer: {
                    Text("All information behålls. Hunden visas som ängel istället för aktiv hund, så du kan fortsätta hedra minnet.")
                }
            }
            .navigationTitle(dogToEdit == nil ? "Lägg till hund" : "Redigera hund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Spara", disabled: !isValid) {
                save()
            }
            .onChange(of: photoItem) {
                loadPickedPhoto()
            }
            .sheet(item: $cropCandidate) { candidate in
                ImageCropView(image: candidate.image, outputSide: 800) { data in
                    photoData = data
                }
            }
        }
    }

    private func loadPickedPhoto() {
        guard let photoItem else { return }
        Task {
            // Öppna beskärningen med originalet — användaren väljer själv
            // utsnitt och zoom innan bilden komprimeras.
            if let data = try? await photoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                cropCandidate = CropCandidate(image: image)
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
            dogToEdit.photoData = photoData
            dogToEdit.color = trimmedOrNil(color)
            dogToEdit.registrationNumber = trimmedOrNil(registrationNumber)
            dogToEdit.chipNumber = trimmedOrNil(chipNumber)
            dogToEdit.breeder = trimmedOrNil(breeder)
            dogToEdit.normalTemperatureCelsius = parsedNormalTemp
            dogToEdit.passedAwayDate = isDeceased ? passedAwayDate : nil
            SyncCoordinator.shared.dogProfileTouched(dogToEdit)
        } else {
            let dog = Dog(
                name: trimmedName,
                breed: resolvedBreed,
                birthDate: birthDate,
                sex: sex
            )
            // Knyt hunden till det inloggade kontot (kontobyten på samma
            // enhet ska inte visa varandras hundar).
            dog.ownerUid = AuthService.shared.currentUserID
            dog.passedAwayDate = isDeceased ? passedAwayDate : nil
            dog.photoData = photoData
            dog.color = trimmedOrNil(color)
            dog.registrationNumber = trimmedOrNil(registrationNumber)
            dog.chipNumber = trimmedOrNil(chipNumber)
            dog.breeder = trimmedOrNil(breeder)
            dog.normalTemperatureCelsius = parsedNormalTemp
            modelContext.insert(dog)
        }
        dismiss()
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var parsedNormalTemp: Double? {
        Double(normalTempText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
    }
}

#Preview {
    AddDogView()
        .modelContainer(for: Dog.self, inMemory: true)
}
