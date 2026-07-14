//
//  KalenderView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct KalenderView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingStart = false
    @State private var cyclePendingEnd: HeatCycle?
    @State private var cyclePendingDelete: HeatCycle?
    @State private var displayedMonth = Date.now
    @State private var selectedDay: SelectedDay?

    private let calendar = Calendar.current

    private var access: DogAccess {
        DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
    }

    private var ongoingCycle: HeatCycle? {
        dog.heatCycles.first { $0.isOngoing }
    }

    private var completedCycles: [HeatCycle] {
        dog.heatCycles.filter { !$0.isOngoing }
    }

    private var breedReference: BreedReference {
        BreedDataService.shared.reference(forBreed: dog.breed)
    }

    private var prediction: HeatPrediction {
        HeatPredictor.predict(completedCycles: completedCycles, breedReference: breedReference)
    }

    private var historyEntries: [HeatCycleAnalyzer.HistoryEntry] {
        HeatCycleAnalyzer.history(from: dog.heatCycles, breedReference: breedReference)
    }

    var body: some View {
        Group {
            if !access.isModuleVisible(.heat) {
                ModuleNotSharedView()
            } else {
                calendarContent
            }
        }
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var calendarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if dog.tracksHeat {
                    actionCard
                }

                VStack(alignment: .leading, spacing: 12) {
                    MonthCalendarView(
                        displayedMonth: $displayedMonth,
                        heatPhase: heatPhase(for:),
                        isPredicted: isPredictedStartDate,
                        hasNote: hasDiaryEntry,
                        onSelectDay: { day in selectedDay = SelectedDay(date: day) }
                    )
                    .cardStyle()

                    if dog.tracksHeat {
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Circle().fill(Theme.Colors.heat.opacity(HeatPhase.proestrus.fillOpacity)).frame(width: 10, height: 10)
                                Text("Förlöp")
                            }
                            HStack(spacing: 6) {
                                Circle().fill(Theme.Colors.heat.opacity(HeatPhase.estrus.fillOpacity)).frame(width: 10, height: 10)
                                Text("Höglöp")
                            }
                            HStack(spacing: 6) {
                                Circle().strokeBorder(Theme.Colors.heat, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 10, height: 10)
                                Text("Förväntat")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                if dog.tracksHeat {
                    predictionCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Löphistorik (\(historyEntries.count))")
                            .font(Theme.Typography.sectionTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if historyEntries.isEmpty {
                            Text("Inga avslutade löp loggade än.")
                                .font(.footnote)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(historyEntries, id: \.cycle.persistentModelID) { entry in
                                    HeatCycleRow(
                                        entry: entry,
                                        canDelete: access.canModify(entryCreatedByUid: entry.cycle.createdByUid)
                                    ) {
                                        cyclePendingDelete = entry.cycle
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Theme.Colors.screenBackground)
        .task(id: prediction.nextExpectedStartDate) {
            guard let nextStart = prediction.nextExpectedStartDate else {
                NotificationService.cancelHeatPredictionNotification(for: dog)
                return
            }
            guard await NotificationService.requestAuthorizationIfNeeded() else { return }
            await NotificationService.scheduleHeatPredictionNotification(for: dog, predictedStartDate: nextStart)
        }
        .sheet(isPresented: $isPresentingStart) {
            StartHeatCycleView(dog: dog)
        }
        .sheet(item: $cyclePendingEnd) { cycle in
            EndHeatCycleView(cycle: cycle)
        }
        .sheet(item: $selectedDay) { selected in
            DayDetailView(dog: dog, date: selected.date)
        }
        .confirmationDialog(
            "Ta bort löpet?",
            isPresented: Binding(
                get: { cyclePendingDelete != nil },
                set: { isPresented in
                    if !isPresented { cyclePendingDelete = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let cycle = cyclePendingDelete {
                    SyncCoordinator.shared.delete(cycle, of: dog, in: modelContext)
                }
                cyclePendingDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                cyclePendingDelete = nil
            }
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        if let ongoingCycle {
            VStack(alignment: .leading, spacing: 8) {
                Label(ongoingHeatSummary(ongoingCycle), systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.heat)

                if access.canModify(entryCreatedByUid: ongoingCycle.createdByUid) {
                    Button("Avsluta löp") {
                        cyclePendingEnd = ongoingCycle
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        } else if access.canLog(in: .heat) {
            Button {
                isPresentingStart = true
            } label: {
                Label("Registrera nytt löp", systemImage: "flame")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    @ViewBuilder
    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Prognosdata (\(dog.breed))", systemImage: "info.circle")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.textPrimary)

            if let nextStart = prediction.nextExpectedStartDate {
                Text("Nästa förväntade löp: \(nextStart.formatted(date: .abbreviated, time: .omitted))")
            }
            Text("Intervall: \(prediction.predictedIntervalDays) dagar (\(basisText))")
            Text("Löplängd: ~\(prediction.predictedDurationDays) dagar (\(basisText))")
        }
        .font(.footnote)
        .foregroundStyle(Theme.Colors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var basisText: String {
        switch prediction.basis {
        case .breedReference:
            "rasvärde"
        case .ownHistory:
            "inlärt från \(prediction.learnedFromCycleCount) cykler"
        }
    }

    private func heatPhase(for date: Date) -> HeatPhase? {
        for cycle in dog.heatCycles {
            if let phase = HeatPhase.phase(on: date, in: cycle, calendar: calendar) {
                return phase
            }
        }
        return nil
    }

    private func ongoingHeatSummary(_ cycle: HeatCycle) -> String {
        let start = calendar.startOfDay(for: cycle.startDate)
        let today = calendar.startOfDay(for: .now)
        let day = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let phase = HeatPhase.forDayInCycle(day)
        return "Löp pågår – Dag \(day) · \(phase.displayName)"
    }

    private func isPredictedStartDate(_ date: Date) -> Bool {
        guard let nextStart = prediction.nextExpectedStartDate else { return false }
        return calendar.isDate(date, inSameDayAs: nextStart)
    }

    private func hasDiaryEntry(_ date: Date) -> Bool {
        dog.diaryEntries.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

private struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

private struct HeatCycleRow: View {
    let entry: HeatCycleAnalyzer.HistoryEntry
    var canDelete: Bool = true
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.cycle.startDate.formatted(date: .abbreviated, time: .omitted)) – \(entry.cycle.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                    .font(.headline)
                HStack(spacing: 4) {
                    if let duration = entry.cycle.durationInDays {
                        Text("\(duration) dagar")
                    }
                    if let interval = entry.intervalSincePreviousDays {
                        Text("· Intervall: \(interval) dagar")
                    }
                    if let deviation = entry.deviationFromPredictedDays, deviation != 0 {
                        Text("· \(deviation > 0 ? "+\(deviation)" : "\(deviation)") dagar mot beräknat")
                            .foregroundStyle(Theme.Colors.heat)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            if canDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityLabel("Ta bort löp")
            }
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        KalenderView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, HeatCycle.self], inMemory: true)
}
