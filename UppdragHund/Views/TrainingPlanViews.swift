//
//  TrainingPlanViews.swift
//  UppdragHund
//
//  Skapa, visa och köra träningspass (mallar). Att köra ett pass loggar en
//  TrainingSession för den aktiva hunden.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Skapa / redigera pass

struct NewTrainingPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    let planToEdit: TrainingPlan?
    @State private var title: String
    @State private var note: String
    @State private var exercises: [ExerciseDraft]

    init(plan: TrainingPlan? = nil) {
        planToEdit = plan
        _title = State(initialValue: plan?.title ?? "")
        _note = State(initialValue: plan?.note ?? "")
        _exercises = State(initialValue: (plan?.sortedExercises ?? []).map { ex in
            let goal: ExerciseGoal = ex.targetMeters != nil ? .meters : (ex.reps != nil ? .reps : .minutes)
            return ExerciseDraft(
                name: ex.name,
                activity: ex.activityRaw.flatMap(TrainingActivityType.init(rawValue:)),
                goal: goal,
                value: ex.targetMeters ?? ex.reps ?? ex.targetMinutes ?? 5,
                instruction: ex.instruction ?? ""
            )
        })
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pass") {
                    TextField("Titel", text: $title, prompt: Text("t.ex. Inkallningspass"))
                    TextField("Beskrivning (valfritt)", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section {
                    ForEach($exercises) { $exercise in
                        exerciseEditor($exercise)
                    }
                    .onDelete { exercises.remove(atOffsets: $0) }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        exercises.append(ExerciseDraft())
                    } label: {
                        Label("Lägg till övning", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text("Övningar")
                        Spacer()
                        if !exercises.isEmpty { EditButton() }
                    }
                }
            }
            .navigationTitle(planToEdit == nil ? "Nytt pass" : "Redigera pass")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func exerciseEditor(_ exercise: Binding<ExerciseDraft>) -> some View {
        let isMeters = exercise.goal.wrappedValue == .meters
        return VStack(alignment: .leading, spacing: 8) {
            TextField("Övningens namn", text: exercise.name, prompt: Text("t.ex. Inkallning"))
                .font(.body.weight(.medium))
            Picker("Typ", selection: exercise.activity) {
                Text("Egen").tag(TrainingActivityType?.none)
                ForEach(TrainingActivityType.allCases) { type in
                    Text(type.displayName).tag(Optional(type))
                }
            }
            Picker("Mål", selection: exercise.goal) {
                ForEach(ExerciseGoal.allCases) { goal in
                    Text(goal.displayName).tag(goal)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: exercise.goal.wrappedValue) { _, newGoal in
                exercise.value.wrappedValue = newGoal.defaultValue
            }
            Stepper(
                "\(exercise.value.wrappedValue)\(isMeters ? " m" : "")",
                value: exercise.value,
                in: isMeters ? 10...5000 : 1...240,
                step: isMeters ? 10 : 1
            )
            TextField("Instruktion (valfritt)", text: exercise.instruction, axis: .vertical)
                .font(.caption)
                .lineLimit(1...3)
        }
        .padding(.vertical, 4)
    }

    private func save() {
        let plan = planToEdit ?? TrainingPlan(
            title: "",
            authorUid: authService.currentUserID,
            authorName: currentUser.profile?.displayName
        )
        plan.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note

        if planToEdit == nil {
            modelContext.insert(plan)
        } else {
            for exercise in plan.exercises { modelContext.delete(exercise) }
            plan.exercises = []
        }

        for (index, draft) in exercises.enumerated() {
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let exercise = TrainingPlanExercise(
                name: name.isEmpty ? (draft.activity?.displayName ?? "Övning") : name,
                activityRaw: draft.activity?.rawValue,
                targetMinutes: draft.goal == .minutes ? draft.value : nil,
                reps: draft.goal == .reps ? draft.value : nil,
                targetMeters: draft.goal == .meters ? draft.value : nil,
                instruction: draft.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.instruction,
                order: index
            )
            exercise.plan = plan
            modelContext.insert(exercise)
        }
        try? modelContext.save()
        dismiss()
    }

    struct ExerciseDraft: Identifiable {
        let id = UUID()
        var name: String = ""
        var activity: TrainingActivityType? = nil
        var goal: ExerciseGoal = .minutes
        var value: Int = 5
        var instruction: String = ""
    }
}

// MARK: - Passdetalj

struct TrainingPlanDetailView: View {
    let plan: TrainingPlan
    let dog: Dog

    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var isRunning = false
    @State private var isEditing = false
    @State private var isSharing = false
    @State private var shareMessage: String?
    @State private var teams: [Team] = []

    var body: some View {
        List {
            if let note = plan.note, !note.isEmpty {
                Section { Text(note).foregroundStyle(Theme.Colors.textSecondary) }
            }
            Section {
                ForEach(plan.sortedExercises) { exercise in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(exercise.name).font(.headline)
                            Spacer()
                            Text(exercise.goalDescription)
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        if let instruction = exercise.instruction, !instruction.isEmpty {
                            Text(instruction).font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
            } header: {
                Text("\(plan.exercises.count) övningar · ca \(plan.totalMinutes) min")
            }
        }
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if DogAccess(dog: dog, currentUid: authService.currentUserID).canLog(in: .training) {
                Button { isRunning = true } label: {
                    Label("Kör passet", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.Colors.brand)
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Menu {
                        Button {
                            share(team: nil)
                        } label: {
                            Label("Alla vänner", systemImage: "person.2")
                        }
                        ForEach(teams) { team in
                            Button {
                                share(team: team)
                            } label: {
                                Label("Bara \(team.name)", systemImage: "person.3.fill")
                            }
                        }
                    } label: {
                        Label("Dela i flödet", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isSharing)
                    Button {
                        isEditing = true
                    } label: {
                        Label("Redigera", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isRunning) { RunTrainingPlanView(plan: plan, dog: dog) }
        .sheet(isPresented: $isEditing) { NewTrainingPlanView(plan: plan) }
        .task {
            if let uid = authService.currentUserID {
                teams = await TeamsRepository.shared.myTeams(uid: uid)
            }
        }
        .alert("Dela pass", isPresented: Binding(
            get: { shareMessage != nil },
            set: { if !$0 { shareMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareMessage ?? "")
        }
    }

    private func share(team: Team?) {
        guard let uid = authService.currentUserID else {
            shareMessage = "Du måste vara inloggad för att dela."
            return
        }
        isSharing = true
        let shared = plan.asShared()
        let name = currentUser.profile?.displayName ?? "Hundägare"
        Task {
            do {
                try await PostsRepository.shared.createPost(
                    authorUid: uid,
                    authorName: name,
                    text: "Delade ett träningspass: \(plan.title)",
                    trainingPlan: shared,
                    team: team
                )
                await MainActor.run {
                    isSharing = false
                    shareMessage = team != nil
                        ? "Passet delades med \(team!.name) 🎉"
                        : "Passet delades i flödet 🎉"
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    shareMessage = "Kunde inte dela passet. Försök igen."
                }
            }
        }
    }
}

// MARK: - Kör passet

struct RunTrainingPlanView: View {
    let plan: TrainingPlan
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var completed: Set<PersistentIdentifier> = []
    @State private var showConfetti = false
    @State private var trackingItem: TrackTarget?

    struct TrackTarget: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let meters: Int
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(plan.sortedExercises) { exercise in
                        HStack(spacing: Theme.Spacing.m) {
                            Button {
                                toggle(exercise)
                            } label: {
                                Image(systemName: completed.contains(exercise.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Theme.Colors.brand)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                if !exercise.goalDescription.isEmpty {
                                    Text(exercise.goalDescription).font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                                }
                                if let instruction = exercise.instruction, !instruction.isEmpty {
                                    Text(instruction).font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            Spacer()
                            if let meters = exercise.targetMeters {
                                Button {
                                    trackingItem = TrackTarget(id: exercise.persistentModelID, name: exercise.name, meters: meters)
                                } label: {
                                    Label("Mät", systemImage: "location.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(Theme.Colors.brand)
                            }
                        }
                    }
                } header: {
                    Text("\(completed.count)/\(plan.exercises.count) klara")
                } footer: {
                    Text("När du slutför loggas passet som ett träningspass för \(dog.name).")
                }
            }
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Slutför") { finish() } }
            }
        }
        .overlay {
            if showConfetti {
                ConfettiView().ignoresSafeArea().transition(.opacity)
            }
        }
        .sheet(item: $trackingItem) { item in
            DistanceTrackerView(
                exerciseName: item.name,
                targetMeters: item.meters,
                onReached: { completed.insert(item.id) }
            )
        }
    }

    private func toggle(_ exercise: TrainingPlanExercise) {
        if completed.contains(exercise.persistentModelID) {
            completed.remove(exercise.persistentModelID)
        } else {
            completed.insert(exercise.persistentModelID)
        }
    }

    private func finish() {
        // Logga bara om behörigheten tillåter (läs-delning ska aldrig skriva).
        if DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID).canLog(in: .training) {
            let session = TrainingSession(
                date: .now,
                activity: plan.title,
                durationMinutes: plan.totalMinutes > 0 ? plan.totalMinutes : nil,
                note: "Pass: \(plan.title)",
                dog: dog
            )
            modelContext.insert(session)
            SyncCoordinator.shared.entryTouched(session, dog: dog)
        }
        withAnimation { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
    }
}

// MARK: - GPS-mätare

struct DistanceTrackerView: View {
    let exerciseName: String
    let targetMeters: Int
    var onReached: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tracker = DistanceTracker()
    @State private var reachedHandled = false

    private var fraction: Double { min(1, tracker.meters / Double(max(1, targetMeters))) }
    private var reached: Bool { tracker.meters >= Double(targetMeters) }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                Text(exerciseName)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)

                ZStack {
                    Circle().stroke(Theme.Colors.textSecondary.opacity(0.2), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(reached ? .green : Theme.Colors.brand, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: fraction)
                    VStack(spacing: 2) {
                        Text("\(Int(tracker.meters))")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("av \(targetMeters) m")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(width: 230, height: 230)

                if reached {
                    Label("Klar!", systemImage: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                } else if tracker.permissionDenied {
                    Text("Platsåtkomst nekad. Slå på under Inställningar → Canine360 → Plats.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()

                Button {
                    if tracker.isTracking { tracker.stop() } else { tracker.start() }
                } label: {
                    Label(
                        tracker.isTracking ? "Pausa" : (tracker.meters > 0 ? "Fortsätt" : "Starta"),
                        systemImage: tracker.isTracking ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(reached ? .green : Theme.Colors.brand)
                .padding(.horizontal)
            }
            .padding(.bottom)
            .overlay {
                if reached { ConfettiView().ignoresSafeArea().allowsHitTesting(false) }
            }
            .navigationTitle("Mät sträcka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Stäng") { tracker.stop(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { finish() } }
            }
            .onChange(of: reached) { _, isReached in
                if isReached && !reachedHandled {
                    reachedHandled = true
                    tracker.stop()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            .onDisappear { tracker.stop() }
        }
    }

    private func finish() {
        tracker.stop()
        onReached()
        dismiss()
    }
}
