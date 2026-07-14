//
//  HundtraningView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct HundtraningView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingNewSession = false
    @State private var sessionPendingDelete: TrainingSession?

    private var sortedSessions: [TrainingSession] {
        dog.trainingSessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if sortedSessions.isEmpty {
                ContentUnavailableView(
                    "Ingen träning loggad",
                    systemImage: "dumbbell",
                    description: Text("Tryck på + för att logga ett träningspass för \(dog.name).")
                )
            } else {
                List {
                    ForEach(sortedSessions) { session in
                        TrainingSessionRow(session: session)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    sessionPendingDelete = session
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Hundträning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Stäng") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewSession = true
                } label: {
                    Label("Logga", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewSession) {
            NewTrainingSessionView(dog: dog)
        }
        .confirmationDialog(
            "Ta bort träningspasset?",
            isPresented: Binding(
                get: { sessionPendingDelete != nil },
                set: { isPresented in
                    if !isPresented { sessionPendingDelete = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let session = sessionPendingDelete {
                    modelContext.delete(session)
                }
                sessionPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                sessionPendingDelete = nil
            }
        }
    }
}

private struct TrainingSessionRow: View {
    let session: TrainingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.activity)
                    .font(.headline)
                Spacer()
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let duration = session.durationMinutes {
                Text("\(duration) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        HundtraningView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, TrainingSession.self], inMemory: true)
}
