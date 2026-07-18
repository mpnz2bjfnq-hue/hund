//
//  ImportFromHealthView.swift
//  UppdragHund
//
//  Listar promenader från Apple Hälsa (inkl. Garmin/Apple Watch) som ännu
//  inte importerats, och låter användaren spara dem som träningspass.
//

import SwiftUI
import SwiftData

struct ImportFromHealthView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workouts: [HealthKitService.Workout] = []
    @State private var alreadyImported: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var importedIDs: Set<String> = []

    private var newWorkouts: [HealthKitService.Workout] {
        workouts.filter { !alreadyImported.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Hämtar från Hälsa…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView("Kunde inte läsa Hälsa", systemImage: "heart.slash", description: Text(errorMessage))
                } else if newWorkouts.isEmpty {
                    ContentUnavailableView(
                        "Inget nytt att importera",
                        systemImage: "checkmark.circle",
                        description: Text("Promenader du gått med Garmin, Apple Watch eller telefonen dyker upp här när de synkats till Apple Hälsa.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(newWorkouts) { workout in
                                row(workout)
                            }
                        } footer: {
                            Text("Importeras som träningspass för \(dog.name). Redan importerade döljs.")
                        }
                    }
                }
            }
            .navigationTitle("Importera från Hälsa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
                if !newWorkouts.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Importera alla") { importAll() }
                    }
                }
            }
            .task { await load() }
        }
    }

    private func row(_ workout: HealthKitService.Workout) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "figure.walk")
                .font(.title3)
                .foregroundStyle(Theme.Colors.brand)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(workout.activityName) · \(workout.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(summary(workout))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            if importedIDs.contains(workout.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.brand)
            } else {
                Button("Importera") { importOne(workout) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(Theme.Colors.brand)
            }
        }
    }

    private func summary(_ w: HealthKitService.Workout) -> String {
        var parts = ["\(w.durationMinutes) min"]
        if let m = w.distanceMeters, m > 0 {
            parts.append(m >= 1000 ? String(format: "%.2f km", m / 1000) : "\(Int(m)) m")
        }
        if let s = w.steps, s > 0 { parts.append("\(s) steg") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Data

    private func load() async {
        do {
            try await HealthKitService.shared.requestAuthorization()
            workouts = try await HealthKitService.shared.recentWalks()
            // Vilka HK-UUID:n som redan finns lokalt.
            let existing = try modelContext.fetch(FetchDescriptor<TrainingSession>())
            alreadyImported = Set(existing.compactMap(\.healthKitUUID))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func importOne(_ workout: HealthKitService.Workout) {
        guard !importedIDs.contains(workout.id) else { return }
        let session = TrainingSession(
            date: workout.date,
            activity: workout.activityName,
            durationMinutes: workout.durationMinutes,
            distanceMeters: workout.distanceMeters.flatMap { $0 > 0 ? $0 : nil },
            dog: dog
        )
        session.steps = workout.steps.flatMap { $0 > 0 ? $0 : nil }
        session.healthKitUUID = workout.id
        modelContext.insert(session)
        try? modelContext.save()
        SyncCoordinator.shared.entryTouched(session, dog: dog)
        importedIDs.insert(workout.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func importAll() {
        for workout in newWorkouts where !importedIDs.contains(workout.id) {
            importOne(workout)
        }
    }
}
