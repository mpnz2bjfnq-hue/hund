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
                    SyncCoordinator.shared.delete(session, of: dog, in: modelContext)
                }
                sessionPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                sessionPendingDelete = nil
            }
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
                    Button {
                        if session.routeData != nil { sessionShowingRoute = session }
                    } label: {
                        TrainingSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
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
            .sheet(item: $sessionShowingRoute) { session in
                RouteMapView(session: session)
            }
        }
    }

    @ViewBuilder private var plansContent: some View {
        if plans.isEmpty {
            ContentUnavailableView(
                "Inga pass än",
                systemImage: "list.bullet.rectangle",
                description: Text("Tryck på + för att skapa ett träningspass du kan köra – och dela med vänner senare.")
            )
        } else {
            List {
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
                } label: {
                    Image(systemName: "plus")
                }
            }
        case .plans:
            Button { isPresentingNewPlan = true } label: { Label("Nytt pass", systemImage: "plus") }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
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
            if session.durationMinutes != nil || session.distanceText != nil {
                HStack(spacing: 4) {
                    Text([session.durationMinutes.map { "\($0) min" }, session.distanceText]
                        .compactMap { $0 }
                        .joined(separator: " · "))
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
