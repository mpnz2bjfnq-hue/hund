//
//  HomeShortcut.swift
//  UppdragHund
//
//  Anpassningsbara genvägar på Hem. Användaren väljer själv vilka som visas
//  (lägga till/ta bort). Valet sparas i UserDefaults via @AppStorage-nyckeln
//  `homeShortcuts` som en kommaseparerad lista av rawValues.
//

import SwiftUI

enum HomeShortcut: String, CaseIterable, Identifiable {
    case health, stats, training, food, profile, export, reminders, diary, places, sitter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health:   String(localized: "Hälsa")
        case .stats:    String(localized: "Statistik")
        case .training: String(localized: "Träning")
        case .food:     String(localized: "Foder")
        case .profile:  String(localized: "Hundprofil")
        case .export:   String(localized: "Exportera PDF")
        case .reminders: String(localized: "Påminnelser")
        case .diary:    String(localized: "Dagbok")
        case .places:   String(localized: "Nära dig")
        case .sitter:   String(localized: "Hundvakt")
        }
    }

    var icon: String {
        switch self {
        case .health:   "stethoscope"
        case .stats:    "chart.bar.fill"
        case .training: "figure.run"
        case .food:     "fork.knife"
        case .profile:  "pawprint.fill"
        case .export:   "doc.text"
        case .reminders: "bell.badge"
        case .diary:    "list.clipboard"
        case .places:   "mappin.and.ellipse"
        case .sitter:   "hand.wave.fill"
        }
    }

    @ViewBuilder
    func destination(for dog: Dog) -> some View {
        switch self {
        case .health:   HealthLogView(dog: dog)
        case .stats:    StatistikView(dog: dog)
        case .training: HundtraningView(dog: dog)
        case .food:     FoderdagbokView(dog: dog)
        case .profile:  DogProfileDetailView(dog: dog)
        case .export:   ExportPDFView(dog: dog)
        case .reminders: NotificationsCenterView(dog: dog)
        case .diary:    DagbokView(dog: dog)
        case .places:   NearbyPlacesView()
        case .sitter:   SitterHandoverView(dog: dog)
        }
    }

    /// Genvägarna som visas som standard innan användaren anpassat något.
    static let defaults: [HomeShortcut] = [.diary, .health, .stats, .training, .food]
}

/// Kodning till/från den kommaseparerade sträng som lagras i @AppStorage.
enum HomeShortcutStore {
    static let storageKey = "homeShortcuts"

    static func decode(_ raw: String) -> [HomeShortcut] {
        raw.split(separator: ",").compactMap { HomeShortcut(rawValue: String($0)) }
    }

    static func encode(_ list: [HomeShortcut]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }

    static let defaultRaw = encode(HomeShortcut.defaults)
}
