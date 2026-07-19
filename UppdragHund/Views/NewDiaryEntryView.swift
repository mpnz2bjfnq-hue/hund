//
//  NewDiaryEntryView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData
import PhotosUI

struct NewDiaryEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dog: Dog

    @State private var date = Date.now
    @State private var bleedingLevel = 0
    @State private var swellingLevel = 0
    @State private var appetiteLevel = 3
    @State private var energyLevel = 3
    @State private var mood: DiaryMood = .neutral
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Datum", selection: $date, in: ...Date.now, displayedComponents: .date)
                }

                Section("Symptom") {
                    levelSlider(title: "Blödning", systemImage: "drop.fill", level: $bleedingLevel)
                    levelSlider(title: "Svullnad", systemImage: "circle.fill", level: $swellingLevel)
                    levelSlider(title: "Aptit", systemImage: "fork.knife", level: $appetiteLevel)
                    levelSlider(title: "Energi", systemImage: "bolt.fill", level: $energyLevel)
                }

                Section("Humör") {
                    Picker("Humör", selection: $mood) {
                        ForEach(DiaryMood.allCases) { mood in
                            Text("\(mood.emoji) \(mood.displayName)").tag(mood)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Foto") {
                    PhotosPicker("Välj foto", selection: $photoPickerItem, matching: .images)
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                    }
                }
            }
            .navigationTitle("Logga idag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Spara", celebratesSave: true) {
                save()
            }
            .onChange(of: photoPickerItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        // Komprimera direkt så fotot ryms i molnbackupen och inte
                        // sväller den lokala databasen.
                        photoData = PostImage.makeData(from: image) ?? data
                    }
                }
            }
        }
    }

    private func levelSlider(title: String, systemImage: String, level: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(level.wrappedValue)/5")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(level.wrappedValue) },
                    set: { level.wrappedValue = Int($0.rounded()) }
                ),
                in: 0...5,
                step: 1
            )
        }
        .padding(.vertical, 2)
    }

    private func save() {
        let entry = DiaryEntry(
            date: date,
            bleedingLevel: bleedingLevel,
            swellingLevel: swellingLevel,
            appetiteLevel: appetiteLevel,
            energyLevel: energyLevel,
            mood: mood,
            photoData: photoData,
            dog: dog
        )
        modelContext.insert(entry)
        try? modelContext.save()
        SyncCoordinator.shared.entryTouched(entry, dog: dog)
        dismiss()
    }
}

#Preview {
    NewDiaryEntryView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, DiaryEntry.self], inMemory: true)
}
