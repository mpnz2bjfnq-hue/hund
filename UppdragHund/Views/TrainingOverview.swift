//
//  TrainingOverview.swift
//  UppdragHund
//
//  Översiktsflik för träning: veckomål, streak, veckodiagram och färdigheter.
//

import SwiftUI
import SwiftData
import Charts

struct TrainingOverview: View {
    let dog: Dog
    var onRunPass: () -> Void
    var onLog: () -> Void
    var onWalk: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("weeklyTrainingGoal") private var weeklyGoal = 5

    @State private var showAddSkill = false
    @State private var newSkillName = ""

    private let calendar = Calendar.current

    private var access: DogAccess {
        DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
    }

    private var canLogTraining: Bool { access.canLog(in: .training) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                headerRow
                weekChartCard
                skillsCard
                quickActions
            }
            .padding(Theme.Spacing.l)
        }
        .background(Theme.screenSurface)
        .alert("Ny färdighet", isPresented: $showAddSkill) {
            TextField("t.ex. Rulla runt", text: $newSkillName)
            Button("Lägg till") { addSkill() }
            Button("Avbryt", role: .cancel) { newSkillName = "" }
        }
    }

    // MARK: - Veckomål + streak

    private var sessionsThisWeek: Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return dog.trainingSessions.filter { week.contains($0.date) }.count
    }

    private var streak: Int { DogStats(dog: dog).trainingStreak }

    private var headerRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            goalCard
            streakCard
        }
    }

    private var goalCard: some View {
        let fraction = weeklyGoal > 0 ? min(1, Double(sessionsThisWeek) / Double(weeklyGoal)) : 0
        return HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle().stroke(Theme.Colors.textSecondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Theme.Colors.brand, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(sessionsThisWeek)/\(weeklyGoal)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 2) {
                Text("Veckomål")
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Menu {
                    ForEach(3...10, id: \.self) { value in
                        Button("\(value) pass/vecka") { weeklyGoal = value }
                    }
                } label: {
                    Text(sessionsThisWeek >= weeklyGoal ? "Klart! 🎉" : "\(weeklyGoal - sessionsThisWeek) kvar")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.brand)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var unlockedAchievements: Int {
        let stats = DogStats(dog: dog)
        return Achievement.allCases.filter { $0.isUnlocked(for: stats) }.count
    }

    private var streakCard: some View {
        NavigationLink {
            AchievementsView(dog: dog)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(streak > 0 ? .orange : Theme.Colors.textSecondary)
                    .symbolEffect(.pulse, isActive: streak > 0)
                Text("\(streak)")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(streak == 1 ? "dag i rad" : "dagar i rad")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text("🏅 \(unlockedAchievements)/\(Achievement.allCases.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
                    .padding(.top, 1)
            }
            .frame(width: 96)
            .padding(.vertical, Theme.Spacing.m)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Veckodiagram

    private struct DayMinutes: Identifiable {
        let id = UUID()
        let date: Date
        let minutes: Int
    }

    private var weekData: [DayMinutes] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return [] }
        let start = calendar.startOfDay(for: week.start)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let minutes = dog.trainingSessions
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .compactMap(\.durationMinutes)
                .reduce(0, +)
            return DayMinutes(date: day, minutes: minutes)
        }
    }

    private var weekTotal: Int { weekData.reduce(0) { $0 + $1.minutes } }

    private var weekTotalMeters: Double {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return dog.trainingSessions
            .filter { week.contains($0.date) }
            .compactMap(\.distanceMeters)
            .reduce(0, +)
    }

    private var weekDistanceText: String? {
        guard weekTotalMeters > 0 else { return nil }
        if weekTotalMeters >= 1000 { return String(format: "%.1f km", weekTotalMeters / 1000) }
        return "\(Int(weekTotalMeters)) m"
    }

    private var weekChartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Denna vecka")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text([Optional("\(weekTotal) min"), weekDistanceText, Optional("\(sessionsThisWeek) pass")]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Chart(weekData) { day in
                BarMark(
                    x: .value("Dag", day.date, unit: .day),
                    y: .value("Minuter", day.minutes)
                )
                .foregroundStyle(day.minutes > 0 ? Theme.Colors.brand : Theme.Colors.textSecondary.opacity(0.25))
                .cornerRadius(4)
            }
            .frame(height: 130)
            .chartXAxis {
                AxisMarks(values: weekData.map(\.date)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Färdigheter

    private var sortedSkills: [TrainingSkill] {
        dog.trainingSkills.sorted { $0.order < $1.order }
    }

    private var skillsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Färdigheter")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                if canLogTraining {
                    Button {
                        newSkillName = ""
                        showAddSkill = true
                    } label: {
                        Label("Lägg till", systemImage: "plus")
                            .font(Theme.Typography.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.brand)
                    }
                }
            }

            if sortedSkills.isEmpty {
                Text("Lägg till färdigheter ni tränar på – tryck för att stega Ej börjat → På gång → Behärskar.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedSkills.enumerated()), id: \.element.persistentModelID) { index, skill in
                        Button {
                            if canLogTraining { cycle(skill) }
                        } label: {
                            skillRow(skill)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if canLogTraining {
                                Button(role: .destructive) { delete(skill) } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            }
                        }
                        if index < sortedSkills.count - 1 {
                            Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private func skillRow(_ skill: TrainingSkill) -> some View {
        HStack {
            Text(skill.name)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if skill.level == .mastered {
                Label("Behärskar", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<3) { dot in
                        Circle()
                            .fill(dot < skill.level.filledDots ? Theme.Colors.brand : Theme.Colors.textSecondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    Text(skill.level.displayName)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
    }

    // MARK: - Snabbknappar

    @ViewBuilder
    private var quickActions: some View {
        if !canLogTraining {
            Text("Du har läsbehörighet för \(dog.name) – bara ägaren (eller readWrite-delning) kan logga.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
        } else {
            quickActionButtons
        }
    }

    private var quickActionButtons: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button(action: onWalk) {
                Label("Logga promenad (GPS)", systemImage: "figure.walk").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.brand)
            HStack(spacing: Theme.Spacing.m) {
                Button(action: onRunPass) {
                    Label("Kör pass", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
                Button(action: onLog) {
                    Label("Logga", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
            }
        }
        .controlSize(.large)
    }

    // MARK: - Actions

    private func addSkill() {
        let name = newSkillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let skill = TrainingSkill(name: name, order: sortedSkills.count, dog: dog)
        modelContext.insert(skill)
        try? modelContext.save()
        SyncCoordinator.shared.dogProfileTouched(dog)
        newSkillName = ""
    }

    private func cycle(_ skill: TrainingSkill) {
        skill.level = skill.level.next
        try? modelContext.save()
        SyncCoordinator.shared.dogProfileTouched(dog)
    }

    private func delete(_ skill: TrainingSkill) {
        modelContext.delete(skill)
        try? modelContext.save()
        SyncCoordinator.shared.dogProfileTouched(dog)
    }
}
