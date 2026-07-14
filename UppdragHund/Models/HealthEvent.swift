//
//  HealthEvent.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum HealthEventType: String, Codable, CaseIterable, Identifiable {
    case vetVisit
    case vaccination
    case insemination
    case weighing
    case temperature
    case medication
    case injury
    case note

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vetVisit: "Veterinärbesök"
        case .vaccination: "Vaccination"
        case .insemination: "Insemination"
        case .weighing: "Vägning"
        case .temperature: "Temperatur"
        case .medication: "Medicin"
        case .injury: "Skada"
        case .note: "Anteckning"
        }
    }

    var systemImage: String {
        switch self {
        case .vetVisit: "stethoscope"
        case .vaccination: "syringe"
        case .insemination: "heart.circle"
        case .weighing: "scalemass"
        case .temperature: "thermometer"
        case .medication: "pills"
        case .injury: "bandage"
        case .note: "note.text"
        }
    }
}

enum BodyLocation: String, Codable, CaseIterable, Identifiable {
    case frontLeftLeg
    case frontRightLeg
    case backLeftLeg
    case backRightLeg
    case spine
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frontLeftLeg: "Fram vänster ben"
        case .frontRightLeg: "Fram höger ben"
        case .backLeftLeg: "Bak vänster ben"
        case .backRightLeg: "Bak höger ben"
        case .spine: "Rygg"
        case .other: "Övrigt"
        }
    }
}

@Model
final class HealthEvent {
    var type: HealthEventType
    var title: String
    var date: Date
    var note: String?
    var bodyLocation: BodyLocation?
    var weightKg: Double?
    var temperatureCelsius: Double?
    var dog: Dog?

    init(
        type: HealthEventType,
        title: String,
        date: Date,
        note: String? = nil,
        bodyLocation: BodyLocation? = nil,
        weightKg: Double? = nil,
        temperatureCelsius: Double? = nil,
        dog: Dog? = nil
    ) {
        self.type = type
        self.title = title
        self.date = date
        self.note = note
        self.bodyLocation = bodyLocation
        self.weightKg = weightKg
        self.temperatureCelsius = temperatureCelsius
        self.dog = dog
    }
}

extension Array where Element == HealthEvent {
    var weighingsSortedByDate: [HealthEvent] {
        filter { $0.type == .weighing && $0.weightKg != nil }
            .sorted { $0.date < $1.date }
    }
}
