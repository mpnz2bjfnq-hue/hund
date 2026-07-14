//
//  FoderdagbokView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct FoderdagbokView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingNewEntry = false
    @State private var entryPendingDelete: MealEntry?

    private var sortedEntries: [MealEntry] {
        dog.mealEntries.sorted { $0.time > $1.time }
    }

    private var groupedByDay: [(day: Date, entries: [MealEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedEntries) { calendar.startOfDay(for: $0.time) }
        return grouped.keys.sorted(by: >).map { day in
            (day, grouped[day]!.sorted { $0.time > $1.time })
        }
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                ContentUnavailableView(
                    "Inga måltider loggade",
                    systemImage: "fork.knife",
                    description: Text("Tryck på + för att logga en måltid eller ett snack för \(dog.name).")
                )
            } else {
                List {
                    ForEach(groupedByDay, id: \.day) { group in
                        Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                            ForEach(group.entries) { entry in
                                MealEntryRow(entry: entry)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            entryPendingDelete = entry
                                        } label: {
                                            Label("Ta bort", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Foderdagbok")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Stäng") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewEntry = true
                } label: {
                    Label("Logga", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewEntry) {
            NewMealEntryView(dog: dog)
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
                    modelContext.delete(entry)
                }
                entryPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                entryPendingDelete = nil
            }
        }
    }
}

private struct MealEntryRow: View {
    let entry: MealEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.type.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.type.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.15), in: Capsule())
                    Text(entry.time.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.name)
                    .font(.headline)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        FoderdagbokView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, MealEntry.self], inMemory: true)
}
