//
//  HealthEvent.swift
//  UppdragHund
//

import Foundation
import CoreGraphics
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

/// Vy på kroppskartan som en skada markeras i. Rå-strängen lagras på
/// HealthEvent; asset-namnet pekar på schäfer-bilderna i asset-katalogen.
enum BodyView: String, Codable, CaseIterable, Identifiable {
    case left, right, front, back, top, bottom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left:   "Vänster"
        case .right:  "Höger"
        case .front:  "Framifrån"
        case .back:   "Bakifrån"
        case .top:    "Ovanifrån"
        case .bottom: "Undersida"
        }
    }

    var assetName: String {
        switch self {
        case .left:   "bodymap_vanster"
        case .right:  "bodymap_hoger"
        case .front:  "bodymap_fram"
        case .back:   "bodymap_bak"
        case .top:    "bodymap_ovan"
        case .bottom: "bodymap_under"
        }
    }
}

/// Läk-status för en skada.
enum HealingStatus: String, Codable, CaseIterable, Identifiable {
    case active, healing, healed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:  "Aktiv"
        case .healing: "Läker"
        case .healed:  "Läkt"
        }
    }
}

@Model
final class HealthEvent {
    var remoteID: UUID?
    // Synk/delning: nil createdByUid = skapad av hundens ägare på egna enheten.
    var createdByUid: String?
    var createdByName: String?
    var updatedAt: Date?
    var pendingUpload: Bool = false
    var type: HealthEventType
    var title: String
    var date: Date
    var note: String?
    var bodyLocation: BodyLocation?
    var weightKg: Double?
    var temperatureCelsius: Double?
    // Skada på kroppskartan: vilken vy och var (normaliserat 0–1), plus
    // läk-status. Optional så äldre poster och andra typer avkodas oförändrat.
    var injuryViewRaw: String?
    var injuryX: Double?
    var injuryY: Double?
    var injuryStatusRaw: String?
    var dog: Dog?

    /// Skadans vy på kroppskartan, om satt.
    var injuryView: BodyView? {
        get { injuryViewRaw.flatMap(BodyView.init(rawValue:)) }
        set { injuryViewRaw = newValue?.rawValue }
    }

    /// Skadans läk-status, om satt.
    var injuryStatus: HealingStatus? {
        get { injuryStatusRaw.flatMap(HealingStatus.init(rawValue:)) }
        set { injuryStatusRaw = newValue?.rawValue }
    }

    /// Markörens normaliserade position (0–1) i vyn, om satt.
    var injuryPoint: CGPoint? {
        get {
            guard let x = injuryX, let y = injuryY else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            injuryX = newValue.map { Double($0.x) }
            injuryY = newValue.map { Double($0.y) }
        }
    }

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
        self.remoteID = UUID()
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
