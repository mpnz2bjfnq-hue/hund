//
//  DagbokView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct DagbokView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingNewEntry = false
    @State private var selectedSegment = Segment.symptom
    @State private var entryPendingDelete: DiaryEntry?

    private enum Segment: String, CaseIterable {
        case symptom = "Symptom"
        case photos = "Foton"
    }

    private var sortedEntries: [DiaryEntry] {
        dog.diaryEntries.sorted { $0.date > $1.date }
    }

    private var entriesWithPhotos: [DiaryEntry] {
        sortedEntries.filter { $0.photoData != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Vy", selection: $selectedSegment) {
                ForEach(Segment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedSegment {
            case .symptom:
                symptomList
            case .photos:
                photoGrid
            }
        }
        .navigationTitle("Dagbok")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewEntry = true
                } label: {
                    Label("Logga idag", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewEntry) {
            NewDiaryEntryView(dog: dog)
        }
        .confirmationDialog(
            "Ta bort loggposten?",
            isPresented: Binding(
                get: { entryPendingDelete != nil },
                set: { isPresented in
                    if !isPresented { entryPendingDelete = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let entry = entryPendingDelete {
                    SyncCoordinator.shared.delete(entry, of: dog, in: modelContext)
                }
                entryPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                entryPendingDelete = nil
            }
        }
    }

    @ViewBuilder
    private var symptomList: some View {
        if sortedEntries.isEmpty {
            ContentUnavailableView(
                "Inga loggar än",
                systemImage: "list.clipboard",
                description: Text("Tryck på + för att logga hur \(dog.name) mår idag.")
            )
        } else {
            List {
                ForEach(sortedEntries) { entry in
                    NavigationLink {
                        DiaryEntryDetailView(entry: entry)
                    } label: {
                        DiaryEntryRow(entry: entry)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            entryPendingDelete = entry
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var photoGrid: some View {
        if entriesWithPhotos.isEmpty {
            ContentUnavailableView(
                "Inga foton än",
                systemImage: "photo",
                description: Text("Lägg till ett foto när du loggar en dag.")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                    ForEach(entriesWithPhotos) { entry in
                        if let data = entry.photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipped()
                        }
                    }
                }
            }
        }
    }
}

private struct DiaryEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Spacer()
                Text(entry.mood.emoji)
                    .font(.title3)
            }
            HStack(spacing: 16) {
                levelLabel("Blödning", systemImage: "drop.fill", level: entry.bleedingLevel)
                levelLabel("Svullnad", systemImage: "circle.fill", level: entry.swellingLevel)
            }
            HStack(spacing: 12) {
                Text("Aptit: \(entry.appetiteLevel)/5")
                Text("Energi: \(entry.energyLevel)/5")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func levelLabel(_ title: String, systemImage: String, level: Int) -> some View {
        HStack(spacing: 2) {
            Text(title + ":")
                .font(.caption)
                .foregroundStyle(.secondary)
            if level == 0 {
                Text("–")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(0..<level, id: \.self) { _ in
                    Image(systemName: systemImage)
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DagbokView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, DiaryEntry.self], inMemory: true)
}
