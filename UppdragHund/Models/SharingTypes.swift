//
//  SharingTypes.swift
//  UppdragHund
//

import Foundation

/// De datamoduler en ägare kan välja att dela per hund.
/// Hundprofilen (namn, ras, födelsedatum, kön) delas alltid och är ingen modul.
enum SharedModule: String, Codable, CaseIterable, Identifiable {
    case health
    case heat
    case diary
    case meals
    case training

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .health: String(localized: "Hälsologg")
        case .heat: String(localized: "Löpcykler")
        case .diary: String(localized: "Dagbok")
        case .meals: String(localized: "Foderdagbok")
        case .training: String(localized: "Träning")
        }
    }

    var systemImage: String {
        switch self {
        case .health: "heart.text.square"
        case .heat: "calendar"
        case .diary: "book"
        case .meals: "fork.knife"
        case .training: "figure.run"
        }
    }

    /// Namnet på subkollektionen under sharedDogs/{dogRemoteID} i Firestore.
    var collectionName: String {
        switch self {
        case .health: "healthEvents"
        case .heat: "heatCycles"
        case .diary: "diaryEntries"
        case .meals: "mealEntries"
        case .training: "trainingSessions"
        }
    }
}

enum SharePermission: String, Codable, CaseIterable, Identifiable {
    case read
    case readWrite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .read: String(localized: "Läsa")
        case .readWrite: String(localized: "Läsa och logga")
        }
    }
}

extension Set where Element == SharedModule {
    /// Kommaseparaterad rawValue-sträng för lagring i SwiftData.
    var rawStorage: String {
        map(\.rawValue).sorted().joined(separator: ",")
    }

    init(rawStorage: String?) {
        guard let rawStorage, !rawStorage.isEmpty else {
            self = []
            return
        }
        self = Set(rawStorage.split(separator: ",").compactMap { SharedModule(rawValue: String($0)) })
    }
}
