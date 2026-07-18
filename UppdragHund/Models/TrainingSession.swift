//
//  TrainingSession.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum TrainingActivityType: String, Codable, CaseIterable, Identifiable {
    case recall
    case heel
    case sitDownStay
    case retrieving
    case noseWork
    case agility
    case puppyClass
    case obedience
    case socialization

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recall: String(localized: "Inkallning")
        case .heel: String(localized: "Fot")
        case .sitDownStay: String(localized: "Sitt/Ligg/Stanna")
        case .retrieving: String(localized: "Apportering")
        case .noseWork: String(localized: "Sök")
        case .agility: String(localized: "Agility")
        case .puppyClass: String(localized: "Valpkurs")
        case .obedience: String(localized: "Lydnad")
        case .socialization: String(localized: "Socialisering")
        }
    }
}

@Model
final class TrainingSession {
    var remoteID: UUID?
    // Synk/delning: nil createdByUid = skapad av hundens ägare på egna enheten.
    var createdByUid: String?
    var createdByName: String?
    var updatedAt: Date?
    var pendingUpload: Bool = false
    var date: Date
    var activity: String
    var durationMinutes: Int?
    var distanceMeters: Double?
    /// GPS-rutt som JSON av [[lat, lon], …]. Sätts av promenad-loggaren.
    var routeData: Data?
    var note: String?
    var dog: Dog?

    init(
        date: Date,
        activity: String,
        durationMinutes: Int? = nil,
        distanceMeters: Double? = nil,
        note: String? = nil,
        dog: Dog? = nil
    ) {
        self.remoteID = UUID()
        self.date = date
        self.activity = activity
        self.durationMinutes = durationMinutes
        self.distanceMeters = distanceMeters
        self.note = note
        self.dog = dog
    }

    /// Formaterad sträcka, t.ex. "850 m" eller "3,2 km".
    var distanceText: String? {
        guard let distanceMeters, distanceMeters > 0 else { return nil }
        if distanceMeters >= 1000 {
            return String(format: "%.1f km", distanceMeters / 1000)
        }
        return "\(Int(distanceMeters)) m"
    }

    /// Avkodad GPS-rutt som (lat, lon)-par.
    var routeCoordinates: [(latitude: Double, longitude: Double)] {
        guard let routeData,
              let pairs = try? JSONDecoder().decode([[Double]].self, from: routeData) else { return [] }
        return pairs.compactMap { $0.count == 2 ? (latitude: $0[0], longitude: $0[1]) : nil }
    }

    static func encodeRoute(_ coordinates: [(latitude: Double, longitude: Double)]) -> Data? {
        guard !coordinates.isEmpty else { return nil }
        return try? JSONEncoder().encode(coordinates.map { [$0.latitude, $0.longitude] })
    }
}
