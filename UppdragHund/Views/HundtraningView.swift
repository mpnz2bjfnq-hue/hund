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
    @Query(sort: \TrainingPlan.createdAt, order: .reverse) private var allPlans: [TrainingPlan]

    /// Bara det inloggade kontots pass (kontobyte ska inte visa andras).
    private var plans: [TrainingPlan] {
        allPlans.filter { $0.authorUid == nil || $0.authorUid == AuthService.shared.currentUserID }
    }
    @State private var segment: TrainingTab = .overview
    @State private var isPresentingNewSession = false
    @State private var isPresentingNewPlan = false
    @State private var isPresentingWalk = false
    @State private var isPresentingHealthImport = false
    @State private var sessionPendingDelete: TrainingSession?
    @State private var sessionShowingRoute: TrainingSession?

    private enum TrainingTab: Hashable { case overview, log, plans }

    private var access: DogAccess {
        DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
    }

    private var sortedSessions: [TrainingSession] {
        dog.trainingSessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Vy", selection: $segment) {
                Text("Översikt").tag(TrainingTab.overview)
                Text("Pass").tag(TrainingTab.plans)
                Text("Logg").tag(TrainingTab.log)
            }
            .pickerStyle(.segmented)
            .padding()

            switch segment {
            case .overview:
                TrainingOverview(
                    dog: dog,
                    onRunPass: { segment = .plans },
                    onLog: { isPresentingNewSession = true },
                    onWalk: { isPresentingWalk = true }
                )
            case .log:   logContent
            case .plans: plansContent
            }
        }
        .navigationTitle("Hundträning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { primaryActionButton }
        }
        .sheet(isPresented: $isPresentingNewSession) {
            NewTrainingSessionView(dog: dog)
        }
        .sheet(isPresented: $isPresentingNewPlan) {
            NewTrainingPlanView()
        }
        .sheet(isPresented: $isPresentingWalk) {
            WalkTrackerView(dog: dog)
        }
        .sheet(isPresented: $isPresentingHealthImport) {
            ImportFromHealthView(dog: dog)
        }
    }

    @ViewBuilder private var logContent: some View {
        if !access.isModuleVisible(.training) {
            ModuleNotSharedView()
        } else if sortedSessions.isEmpty {
            ContentUnavailableView(
                "Ingen träning loggad",
                systemImage: "dumbbell",
                description: Text(access.canLog(in: .training)
                    ? "Tryck på + för att logga träning för \(dog.name)."
                    : "Inget loggat än.")
            )
        } else {
            List {
                ForEach(sortedSessions) { session in
                    // Raden är INTE en Button — en Button slåss med svepet och
                    // stänger det direkt. Rutten öppnas via tap på hela raden.
                    TrainingSessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if session.routeData != nil { sessionShowingRoute = session }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if access.canModify(entryCreatedByUid: session.createdByUid) {
                                Button(role: .destructive) {
                                    sessionPendingDelete = session
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            }
                        }
                        .contextMenu {
                            if session.routeData != nil {
                                Button {
                                    sessionShowingRoute = session
                                } label: {
                                    Label("Visa rutt", systemImage: "map")
                                }
                            }
                            if access.canModify(entryCreatedByUid: session.createdByUid) {
                                Button(role: .destructive) {
                                    sessionPendingDelete = session
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            // Bekräftelsen ligger på listan, inte per rad — så den överlever
            // att raden slutar renderas medan svepet stänger.
            .confirmationDialog(
                "Ta bort träningspasset?",
                isPresented: Binding(
                    get: { sessionPendingDelete != nil },
                    set: { if !$0 { sessionPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Ta bort", role: .destructive) {
                    if let session = sessionPendingDelete {
                        SyncCoordinator.shared.delete(session, of: dog, in: modelContext)
                    }
                    sessionPendingDelete = nil
                }
                Button("Avbryt", role: .cancel) { sessionPendingDelete = nil }
            }
            .sheet(item: $sessionShowingRoute) { session in
                RouteMapView(session: session)
            }
        }
    }

    /// Spellista med träningsvideor — alltid länkad under Pass.
    private static let trainingPlaylistURL =
        URL(string: "https://youtube.com/playlist?list=PLOYwYhLsoScpxGR6IUs4yoo0-TILsmrFm")!

    @ViewBuilder private var plansContent: some View {
        List {
            Section {
                Link(destination: Self.trainingPlaylistURL) {
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Träningstips på YouTube")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text("Spellista med videor att träna efter")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if plans.isEmpty {
                ContentUnavailableView(
                    "Inga pass än",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Tryck på + för att skapa ett träningspass du kan köra – och dela med vänner senare.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("Mina pass") {
                    ForEach(plans) { plan in
                        NavigationLink {
                            TrainingPlanDetailView(plan: plan, dog: dog)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title).font(.headline)
                                Text("\(plan.exercises.count) övningar · ca \(plan.totalMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deletePlans)
                }
            }
        }
    }

    @ViewBuilder private var primaryActionButton: some View {
        switch segment {
        case .overview:
            EmptyView()
        case .log:
            if access.canLog(in: .training) {
                Menu {
                    Button { isPresentingNewSession = true } label: {
                        Label("Logga träning", systemImage: "square.and.pencil")
                    }
                    Button { isPresentingWalk = true } label: {
                        Label("Logga promenad (GPS)", systemImage: "figure.walk")
                    }
                    if HealthKitService.shared.isAvailable {
                        Button { isPresentingHealthImport = true } label: {
                            Label("Importera från Hälsa", systemImage: "heart.text.square")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        case .plans:
            Button { isPresentingNewPlan = true } label: { Label("Nytt pass", systemImage: "plus") }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        let uid = AuthService.shared.currentUserID
        let removedIDs = offsets.compactMap { plans[$0].remoteID }
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
        // Ta bort passen ur molnbackupen så de inte återuppstår vid nästa synk.
        if let uid {
            Task {
                for id in removedIDs { await TrainingPlanBackupService.deleteBackup(planRemoteID: id, uid: uid) }
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
            let stats = [
                session.durationMinutes.map { "\($0) min" },
                session.distanceText,
                session.averageSpeedText,
                session.stepsText,
            ].compactMap { $0 }
            if !stats.isEmpty {
                HStack(spacing: 4) {
                    Text(stats.joined(separator: " · "))
                    if session.routeData != nil {
                        Image(systemName: "map")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let note = session.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LoggedByLine(name: session.createdByName)
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
