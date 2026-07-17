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
    @AppStorage("heatRemindersEnabled") private var heatRemindersEnabled = true

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
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Kalender")
            }
        }
    }

    private var calendarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if dog.tracksHeat {
                    actionCard

                    if let ongoingCycle {
                        HeatGuideCard(currentDay: dayInOngoing(ongoingCycle))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    MonthCalendarView(
                        displayedMonth: $displayedMonth,
                        heatPhase: heatPhase(for:),
                        isTestDay: isTestDate,
                        isPredicted: isPredictedStartDate,
                        hasNote: hasDiaryEntry,
                        hasHealthEvent: hasHealthEvent,
                        onSelectDay: { day in selectedDay = SelectedDay(date: day) }
                    )
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        if dog.tracksHeat {
                            HStack(spacing: 14) {
                                legendItem("Förlöp") {
                                    Circle().fill(Theme.Colors.heat.opacity(HeatPhase.proestrus.fillOpacity))
                                }
                                legendItem("Höglöp") {
                                    Circle().fill(Theme.Colors.heat.opacity(HeatPhase.estrus.fillOpacity))
                                }
                                legendItem("Efterlöp") {
                                    Circle()
                                        .fill(Theme.Colors.heat.opacity(HeatPhase.metestrus.fillOpacity))
                                        .overlay(Circle().strokeBorder(Theme.Colors.heat.opacity(0.7), lineWidth: 1.5))
                                }
                            }
                            HStack(spacing: 14) {
                                HStack(spacing: 6) {
                                    Image(systemName: "cross.case.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Theme.Colors.verified)
                                    Text("Provdag")
                                }
                                legendItem("Förväntat löp") {
                                    Circle().strokeBorder(Theme.Colors.heat, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                }
                            }
                        }
                        HStack(spacing: 14) {
                            legendItem("Dagbok", size: 5) { Circle().fill(Color.accentColor) }
                            legendItem("Hälsologg", size: 5) { Circle().fill(Theme.Colors.verified) }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
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
            guard heatRemindersEnabled, let nextStart = prediction.nextExpectedStartDate else {
                NotificationService.cancelHeatPredictionNotification(for: dog)
                return
            }
            guard await NotificationService.requestAuthorizationIfNeeded() else { return }
            await NotificationService.scheduleHeatPredictionNotification(for: dog, predictedStartDate: nextStart)
        }
        .task(id: ongoingCycle?.startDate) {
            guard heatRemindersEnabled, let ongoing = ongoingCycle else {
                NotificationService.cancelOngoingHeatNotifications(for: dog)
                return
            }
            guard await NotificationService.requestAuthorizationIfNeeded() else { return }
            await NotificationService.scheduleOngoingHeatNotifications(for: dog, cycleStart: ongoing.startDate)
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

                if HeatPhase.isOverdue(day: dayInOngoing(ongoingCycle)) {
                    overdueNotice(ongoingCycle)
                }

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

    /// Ett löp som ligger kvar förbi taket är nästan alltid glömt. Säg det rakt
    /// ut — annars slutar prognosen tyst att fungera, eftersom nästa förväntade
    /// löp bara räknas fram ur avslutade cykler.
    private func overdueNotice(_ cycle: HeatCycle) -> some View {
        let days = HeatPhase.elapsedDays(in: cycle, calendar: calendar)
        return HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "questionmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Theme.Colors.warning)
            Text("Löpet har varit registrerat i \(days) dagar. Är det avslutat? Kalendern slutar färga efter dag \(HeatPhase.maxOngoingDays), och nästa löp kan inte förutsägas förrän det här är avslutat.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Colors.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        )
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

    private func legendItem<S: View>(
        _ label: String,
        size: CGFloat = 10,
        @ViewBuilder symbol: () -> S
    ) -> some View {
        HStack(spacing: 6) {
            symbol().frame(width: size, height: size)
            Text(label)
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

    private func isTestDate(_ date: Date) -> Bool {
        dog.heatCycles.contains { HeatPhase.isTestDay(on: date, in: $0, calendar: calendar) }
    }

    /// Dag i löpet (1 = startdagen) räknat till idag, utan tak.
    private func dayInOngoing(_ cycle: HeatCycle) -> Int {
        HeatPhase.elapsedDays(in: cycle, calendar: calendar)
    }

    private func ongoingHeatSummary(_ cycle: HeatCycle) -> String {
        let day = dayInOngoing(cycle)
        // Förbi taket vet vi inte längre var i löpet tiken är — påstå ingen fas.
        guard !HeatPhase.isOverdue(day: day) else {
            return "Löp registrerat – Dag \(day)"
        }
        return "Löp pågår – Dag \(day) · \(HeatPhase.forDayInCycle(day).swedishCommon)"
    }

    private func isPredictedStartDate(_ date: Date) -> Bool {
        guard let nextStart = prediction.nextExpectedStartDate else { return false }
        return calendar.isDate(date, inSameDayAs: nextStart)
    }

    private func hasDiaryEntry(_ date: Date) -> Bool {
        dog.diaryEntries.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func hasHealthEvent(_ date: Date) -> Bool {
        dog.healthEvents.contains { calendar.isDate($0.date, inSameDayAs: date) }
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
