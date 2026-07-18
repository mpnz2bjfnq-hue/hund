//
//  Canine360Widgets.swift
//  Canine360Widgets
//
//  Hemskärms- och låsskärmswidgets. Läser WidgetSnapshot ur app-gruppen
//  (appen skriver via WidgetDataService) — widgeten pratar aldrig med
//  Firebase eller SwiftData själv.
//

import WidgetKit
import SwiftUI
import UIKit

@main
struct Canine360WidgetBundle: WidgetBundle {
    var body: some Widget {
        KommandeWidget()
        SnapploggaWidget()
    }
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
    let snapshot: WidgetSnapshot?

    static var placeholder: SnapshotEntry {
        let now = Date.now
        return SnapshotEntry(date: now, snapshot: WidgetSnapshot(
            dogName: "Ronja",
            dogBreed: "Schäfer",
            dogPhotoData: nil,
            upcoming: [
                .init(date: now.addingTimeInterval(3600 * 26), title: "Veterinärbesök", subtitle: "Vaccination", kind: .health),
                .init(date: now.addingTimeInterval(3600 * 24 * 3), title: "Hundträff i parken", subtitle: "Stadsparken", kind: .meetup),
                .init(date: now.addingTimeInterval(3600 * 24 * 12), title: "Förväntat löp", subtitle: nil, kind: .heat),
            ],
            generatedAt: now
        ))
    }
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(SnapshotEntry(date: .now, snapshot: WidgetStore.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetStore.load()
        let entry = SnapshotEntry(date: .now, snapshot: snapshot)
        // Uppdatera när nästa händelse passerat, dock senast vid midnatt
        // (så "Om X dagar" räknar ner korrekt).
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        let nextEventDate = snapshot?.upcoming.map(\.date).filter { $0 > .now }.min()
        let refresh = min(nextEventDate ?? midnight, midnight)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
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

    /// Kort svensk datumetikett: "Pågår", "Idag 14:00", "Imorgon", "Om 5 d".
    var dateLabel: String {
        let calendar = Calendar.current
        if date <= .now { return "Pågår" }
        if calendar.isDateInToday(date) {
            return "Idag \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInTomorrow(date) { return "Imorgon" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        if days < 7 { return "Om \(days) d" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

private struct DogHeader: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(spacing: 6) {
            if let data = snapshot.dogPhotoData, let image = UIImage(data: data) {
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
            Text(snapshot.dogName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WidgetTheme.textSecondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Kommande

struct KommandeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KommandeWidget", provider: SnapshotProvider()) { entry in
            KommandeView(entry: entry)
        }
        .configurationDisplayName("Kommande")
        .description("Nästa vet-bokning, förväntat löp och inbokade träffar för din aktiva hund.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct KommandeView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var upcoming: [WidgetSnapshot.Item] {
        entry.snapshot?.upcoming.filter { $0.date > .now || $0.kind == .heat } ?? []
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
            if let snapshot = entry.snapshot {
                DogHeader(snapshot: snapshot)
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
            if let snapshot = entry.snapshot {
                HStack {
                    DogHeader(snapshot: snapshot)
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
            Text("Öppna Canine360 för att synka widgeten.")
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
        if item.date <= .now { return "Nu" }
        if calendar.isDateInToday(item.date) { return "Idag" }
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: item.date)
        ).day ?? 0
        return "\(days) d"
    }
}

// MARK: - Snapplogga

struct SnapploggaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SnapploggaWidget", provider: SnapshotProvider()) { entry in
            SnapploggaView(entry: entry)
        }
        .configurationDisplayName("Snapplogga")
        .description("Genvägar som öppnar appen direkt i rätt loggningsflöde.")
        .supportedFamilies([.systemMedium])
    }
}

struct SnapploggaView: View {
    let entry: SnapshotEntry

    private struct Action: Identifiable {
        let id: String
        let title: String
        let icon: String
        let url: URL
    }

    private let actions: [Action] = [
        Action(id: "halsa", title: "Hälsa", icon: "heart.text.square.fill", url: WidgetDeepLink.logHealth),
        Action(id: "foder", title: "Foder", icon: "fork.knife", url: WidgetDeepLink.logMeal),
        Action(id: "traning", title: "Träning", icon: "figure.run", url: WidgetDeepLink.logTraining),
        Action(id: "dagbok", title: "Dagbok", icon: "book.fill", url: WidgetDeepLink.logDiary),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let snapshot = entry.snapshot {
                    Text("Logga för \(snapshot.dogName)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetTheme.textSecondary)
                } else {
                    Text("Snapplogga")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WidgetTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.brand)
            }
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Link(destination: action.url) {
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
        .containerBackground(WidgetTheme.background, for: .widget)
    }
}
