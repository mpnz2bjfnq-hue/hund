//
//  Canine360Widgets.swift
//  Canine360Widgets
//
//  Hemskärms- och låsskärmswidgets. Läser WidgetSnapshot ur app-gruppen
//  (appen skriver via WidgetDataService) — widgeten pratar aldrig med
//  Firebase eller SwiftData själv. Vilken hund som visas väljs per widget
//  via långtryck → Redigera widget (SelectDogIntent).
//

import WidgetKit
import SwiftUI
import UIKit
import AppIntents

@main
struct Canine360WidgetBundle: WidgetBundle {
    var body: some Widget {
        KommandeWidget()
        SnapploggaWidget()
    }
}

// MARK: - Hundval (widget-konfiguration)

struct DogEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Hund"
    static let defaultQuery = DogEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct DogEntityQuery: EntityQuery {
    private func allDogs() -> [DogEntity] {
        (WidgetStore.load()?.dogs ?? []).map { DogEntity(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [DogEntity] {
        allDogs().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DogEntity] {
        allDogs()
    }

    func defaultResult() async -> DogEntity? {
        let snapshot = WidgetStore.load()
        guard let dog = snapshot?.dog(withID: nil) else { return nil }
        return DogEntity(id: dog.id, name: dog.name)
    }
}

struct SelectDogIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Välj hund"
    static let description = IntentDescription("Vilken hund widgeten visar.")

    @Parameter(title: "Hund")
    var dog: DogEntity?
}

// MARK: - Gemensamt

enum WidgetTheme {
    static let background = Color(red: 0.07, green: 0.09, blue: 0.08)
    static let brand = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    static let heat = Color(red: 0.72, green: 0.47, blue: 0.24)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    /// Vald (eller aktiv) hund ur cachen; nil när cachen saknas helt.
    let dog: WidgetSnapshot.DogData?
    let hasSnapshot: Bool

    static var placeholder: SnapshotEntry {
        let now = Date.now
        return SnapshotEntry(date: now, dog: WidgetSnapshot.DogData(
            id: "placeholder",
            name: "Ronja",
            breed: "Schäfer",
            photoData: nil,
            upcoming: [
                .init(date: now.addingTimeInterval(3600 * 26), title: String(localized: "Veterinärbesök"), subtitle: String(localized: "Vaccination"), kind: .health),
                .init(date: now.addingTimeInterval(3600 * 24 * 3), title: String(localized: "Hundträff i parken"), subtitle: String(localized: "Stadsparken"), kind: .meetup),
                .init(date: now.addingTimeInterval(3600 * 24 * 12), title: String(localized: "Förväntat löp"), subtitle: nil, kind: .heat),
            ],
            canLogModules: ["health", "meals", "training", "diary"]
        ), hasSnapshot: true)
    }
}

struct DogSelectionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { .placeholder }

    func snapshot(for configuration: SelectDogIntent, in context: Context) async -> SnapshotEntry {
        context.isPreview ? .placeholder : entry(for: configuration)
    }

    func timeline(for configuration: SelectDogIntent, in context: Context) async -> Timeline<SnapshotEntry> {
        let entry = entry(for: configuration)
        // Uppdatera när nästa händelse passerat, dock senast vid midnatt
        // (så "Om X dagar" räknar ner korrekt).
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let nextEventDate = entry.dog?.upcoming.map(\.date).filter { $0 > .now }.min()
        let refresh = min(nextEventDate ?? midnight, midnight)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    private func entry(for configuration: SelectDogIntent) -> SnapshotEntry {
        let snapshot = WidgetStore.load()
        return SnapshotEntry(
            date: .now,
            dog: snapshot?.dog(withID: configuration.dog?.id),
            hasSnapshot: snapshot != nil
        )
    }
}

extension WidgetSnapshot.Item {
    var icon: String {
        switch kind {
        case .health: "heart.text.square.fill"
        case .heat: "drop.fill"
        case .meetup: "person.2.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .health: WidgetTheme.brand
        case .heat: WidgetTheme.heat
        case .meetup: WidgetTheme.brand
        }
    }

    /// Kort datumetikett: "Pågår", "Idag 14:00", "Imorgon", "Om 5 d".
    var dateLabel: String {
        let calendar = Calendar.current
        if date <= .now { return String(localized: "Pågår") }
        if calendar.isDateInToday(date) {
            return String(localized: "Idag \(date.formatted(date: .omitted, time: .shortened))")
        }
        if calendar.isDateInTomorrow(date) { return String(localized: "Imorgon") }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        if days < 7 { return String(localized: "Om \(days) d") }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct DogHeader: View {
    let dog: WidgetSnapshot.DogData

    var body: some View {
        HStack(spacing: 6) {
            if let data = dog.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.caption2)
                    .foregroundStyle(WidgetTheme.brand)
            }
            Text(dog.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Kommande

struct KommandeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "KommandeWidget",
            intent: SelectDogIntent.self,
            provider: DogSelectionProvider()
        ) { entry in
            KommandeView(entry: entry)
        }
        .configurationDisplayName("Kommande")
        .description("Nästa vet-bokning, förväntat löp och inbokade träffar. Välj hund med långtryck → Redigera widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct KommandeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var upcoming: [WidgetSnapshot.Item] {
        entry.dog?.upcoming.filter { $0.date > .now || $0.kind == .heat } ?? []
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangular
            case .accessoryCircular: circular
            case .systemMedium: medium
            default: small
            }
        }
        .widgetURL(WidgetDeepLink.home)
    }

    // Hemskärm

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dog = entry.dog {
                DogHeader(dog: dog)
                Spacer(minLength: 0)
                if let next = upcoming.first {
                    Image(systemName: next.icon)
                        .font(.title3)
                        .foregroundStyle(next.tint)
                    Text(next.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetTheme.textPrimary)
                        .lineLimit(2)
                    Text(next.dateLabel)
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.textSecondary)
                } else {
                    emptyState
                }
            } else {
                notSyncedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetTheme.background, for: .widget)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let dog = entry.dog {
                HStack {
                    DogHeader(dog: dog)
                    Spacer()
                    Text("Kommande")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(WidgetTheme.brand)
                }
                if upcoming.isEmpty {
                    Spacer(minLength: 0)
                    emptyState
                    Spacer(minLength: 0)
                } else {
                    ForEach(Array(upcoming.prefix(3).enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.caption)
                                .foregroundStyle(item.tint)
                                .frame(width: 16)
                            Text(item.title)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(WidgetTheme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.dateLabel)
                                .font(.caption2)
                                .foregroundStyle(WidgetTheme.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            } else {
                notSyncedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(WidgetTheme.background, for: .widget)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Inget inbokat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WidgetTheme.textPrimary)
            Text("Njut av dagen 🐾")
                .font(.caption)
                .foregroundStyle(WidgetTheme.textSecondary)
        }
    }

    private var notSyncedState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "pawprint.fill")
                .foregroundStyle(WidgetTheme.brand)
            Text(entry.hasSnapshot
                 ? "Ingen hund att visa. Lägg till en hund i appen."
                 : "Öppna Canine360 för att synka widgeten.")
                .font(.caption)
                .foregroundStyle(WidgetTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // Låsskärm

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next = upcoming.first {
                HStack(spacing: 4) {
                    Image(systemName: next.icon)
                        .font(.caption2)
                    Text(next.dateLabel)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                Text(next.title)
                    .font(.headline)
                    .lineLimit(2)
            } else {
                Text("Inget inbokat")
                    .font(.headline)
                Text("Njut av dagen 🐾")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let next = upcoming.first {
                VStack(spacing: 0) {
                    Image(systemName: next.icon)
                        .font(.caption2)
                    Text(circularDayLabel(for: next))
                        .font(.headline)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.title3)
            }
        }
        .containerBackground(.clear, for: .widget)
    }

    private func circularDayLabel(for item: WidgetSnapshot.Item) -> String {
        let calendar = Calendar.current
        if item.date <= .now { return String(localized: "Nu") }
        if calendar.isDateInToday(item.date) { return String(localized: "Idag") }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: item.date)
        ).day ?? 0
        return String(localized: "\(days) d")
    }
}

// MARK: - Snapplogga

struct SnapploggaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "SnapploggaWidget",
            intent: SelectDogIntent.self,
            provider: DogSelectionProvider()
        ) { entry in
            SnapploggaView(entry: entry)
        }
        .configurationDisplayName("Snapplogga")
        .description("Genvägar som öppnar appen direkt i rätt loggningsflöde. Välj hund med långtryck → Redigera widget.")
        .supportedFamilies([.systemMedium])
    }
}

struct SnapploggaView: View {
    let entry: SnapshotEntry

    private struct Action: Identifiable {
        let id: String
        let title: String
        let icon: String
        /// SharedModule-rawValue som styr om knappen visas för vald hund.
        let module: String
    }

    private let actions: [Action] = [
        Action(id: "halsa", title: String(localized: "Hälsa"), icon: "heart.text.square.fill", module: "health"),
        Action(id: "foder", title: String(localized: "Foder"), icon: "fork.knife", module: "meals"),
        Action(id: "traning", title: String(localized: "Träning"), icon: "figure.run", module: "training"),
        Action(id: "dagbok", title: String(localized: "Dagbok"), icon: "book.fill", module: "diary"),
    ]

    private var allowedActions: [Action] {
        guard let dog = entry.dog else { return actions }
        return actions.filter { dog.canLogModules.contains($0.module) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.dog.map { String(localized: "Logga för \($0.name)") } ?? String(localized: "Snapplogga"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.brand)
            }
            if allowedActions.isEmpty {
                Spacer(minLength: 0)
                Text("Du har läsbehörighet för \(entry.dog?.name ?? String(localized: "hunden")) — be ägaren om loggbehörighet för att snapplogga.")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.textSecondary)
                Spacer(minLength: 0)
            } else {
                HStack(spacing: 8) {
                    ForEach(allowedActions) { action in
                        Link(destination: WidgetDeepLink.log(action.id, dogID: entry.dog?.id)) {
                            VStack(spacing: 6) {
                                Image(systemName: action.icon)
                                    .font(.title3)
                                    .foregroundStyle(WidgetTheme.brand)
                                Text(action.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(WidgetTheme.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                        }
                    }
                }
            }
        }
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}
