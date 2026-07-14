//
//  HemView.swift
//  UppdragHund
//
//  Startflik: aktiv-hund-kort + Översikt (status för hunden idag) + Kommande.
//

import SwiftUI
import SwiftData

struct HemView: View {
    let dog: Dog

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                dogCard
                oversiktSection
                kommandeSection
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Canine360Wordmark(size: 20)
            }
        }
    }

    // MARK: - Aktiv-hund-kort

    private var dogCard: some View {
        NavigationLink {
            DogProfileDetailView(dog: dog)
        } label: {
            HStack(spacing: Theme.Spacing.l) {
                DogAvatar(photoData: dog.photoData, size: 68, isActive: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dog.name)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(dog.breed) · \(dog.sex.displayName)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Född \(dog.birthDate.formatted(date: .abbreviated, time: .omitted)) · \(AgeFormatter.describe(birthDate: dog.birthDate))")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Översikt

    private var oversiktSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Översikt")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("Idag, \(Date.now.formatted(.dateTime.day().month(.wide)))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.m
            ) {
                weightTile
                motionTile
                healthTile
                if dog.tracksHeat {
                    heatTile
                }
            }
        }
    }

    private var weightTile: some View {
        let weighings = dog.healthEvents.weighingsSortedByDate
        let latest = weighings.last?.weightKg
        let previous = weighings.dropLast().last?.weightKg
        let value = latest.map { String(format: "%.1f kg", $0) } ?? "–"
        var delta: String? = nil
        var deltaPositive = true
        if let latest, let previous {
            let diff = latest - previous
            if abs(diff) >= 0.05 {
                delta = String(format: "%@%.1f kg", diff > 0 ? "+" : "", diff)
                deltaPositive = diff > 0
            }
        }
        return StatTile(
            icon: "scalemass.fill", category: "Vikt", value: value,
            delta: delta, deltaPositive: deltaPositive, tint: Theme.Colors.brand
        )
    }

    private var motionTile: some View {
        let todaysMinutes = dog.trainingSessions
            .filter { calendar.isDateInToday($0.date) }
            .compactMap(\.durationMinutes)
            .reduce(0, +)
        return StatTile(
            icon: "figure.walk", category: "Motion",
            value: todaysMinutes > 0 ? "\(todaysMinutes) min" : "–",
            tint: Theme.Colors.brand
        )
    }

    private var healthTile: some View {
        let injuries = dog.healthEvents
            .filter { $0.type == .injury }
            .sorted { $0.date > $1.date }
        let value = injuries.first?.title ?? "Allt bra"
        return StatTile(
            icon: "heart.text.square.fill", category: "Hälsa", value: value,
            tint: injuries.isEmpty ? Theme.Colors.brand : Theme.Colors.warning
        )
    }

    private var heatTile: some View {
        let data = heatTileData
        return StatTile(
            icon: "drop.fill", category: "Löp", value: data.value,
            subtitle: data.subtitle, tint: Theme.Colors.heat
        )
    }

    private var heatTileData: (value: String, subtitle: String?) {
        guard dog.sex == .female else { return ("–", nil) }
        if let ongoing = dog.heatCycles.first(where: { $0.isOngoing }) {
            let start = calendar.startOfDay(for: ongoing.startDate)
            let today = calendar.startOfDay(for: .now)
            let day = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            return ("Dag \(day)", HeatPhase.forDayInCycle(day).displayName)
        }
        if let next = nextHeatDate, next > .now {
            let days = calendar.dateComponents([.day], from: .now, to: next).day ?? 0
            return ("Om \(days) d", "till löp")
        }
        return ("–", nil)
    }

    // MARK: - Kommande

    private var kommandeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Kommande")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                NavigationLink {
                    HealthLogView(dog: dog)
                } label: {
                    Text("Visa alla")
                        .font(Theme.Typography.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.brand)
                }
            }

            if upcomingItems.isEmpty {
                Text("Inget planerat framåt.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingItems.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: item.icon)
                                .font(.body)
                                .foregroundStyle(item.tint)
                                .frame(width: 26)
                            Text(item.title)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(.vertical, Theme.Spacing.m)
                        if index < upcomingItems.count - 1 {
                            Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                .background(
                    Theme.Colors.cardBackground,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                )
            }
        }
    }

    private struct UpcomingItem {
        let date: Date
        let title: String
        let icon: String
        let tint: Color
    }

    private var upcomingItems: [UpcomingItem] {
        var items: [UpcomingItem] = dog.healthEvents
            .filter { $0.date > .now }
            .map { event in
                UpcomingItem(
                    date: event.date,
                    title: event.title.isEmpty ? event.type.displayName : event.title,
                    icon: event.type.systemImage,
                    tint: Theme.Colors.brand
                )
            }
        if dog.sex == .female, let next = nextHeatDate, next > .now {
            items.append(UpcomingItem(
                date: next, title: "Förväntat löp",
                icon: "drop.fill", tint: Theme.Colors.heat
            ))
        }
        return items.sorted { $0.date < $1.date }.prefix(4).map { $0 }
    }

    // MARK: - Löp-prediktion (samma källa som Kalender)

    private var nextHeatDate: Date? {
        let completed = dog.heatCycles.filter { !$0.isOngoing }
        let reference = BreedDataService.shared.reference(forBreed: dog.breed)
        return HeatPredictor.predict(completedCycles: completed, breedReference: reference)
            .nextExpectedStartDate
    }
}

// MARK: - Stat-kort

private struct StatTile: View {
    let icon: String
    let category: String
    let value: String
    var delta: String? = nil
    var deltaPositive: Bool = true
    var subtitle: String? = nil
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text(category)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text(value)
                .font(Theme.Typography.metric)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let delta {
                Text(delta)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(deltaPositive ? Theme.Colors.brand : Theme.Colors.heat)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        HemView(dog: Dog(name: "Sixten", breed: "Malinois", birthDate: .now, sex: .male))
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
