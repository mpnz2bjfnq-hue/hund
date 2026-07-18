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
        case .vetVisit: String(localized: "Veterinärbesök")
        case .vaccination: String(localized: "Vaccination")
        case .insemination: String(localized: "Insemination")
        case .weighing: String(localized: "Vägning")
        case .temperature: String(localized: "Temperatur")
        case .medication: String(localized: "Medicin")
        case .injury: String(localized: "Skada")
        case .note: String(localized: "Anteckning")
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
        case .frontLeftLeg: String(localized: "Fram vänster ben")
        case .frontRightLeg: String(localized: "Fram höger ben")
        case .backLeftLeg: String(localized: "Bak vänster ben")
        case .backRightLeg: String(localized: "Bak höger ben")
        case .spine: String(localized: "Rygg")
        case .other: String(localized: "Övrigt")
        }
    }
}

/// Vy på kroppskartan som en skada markeras i. Två vyer räcker och
/// kompletterar varandra: sidan visar var på kroppen, ovanifrån skiljer
/// vänster/höger. Rå-strängen lagras på HealthEvent.
enum BodyView: String, Codable, CaseIterable, Identifiable {
    case side, top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .side: String(localized: "Sida")
        case .top:  String(localized: "Ovanifrån")
        }
    }

    var assetName: String {
        switch self {
        case .side: "bodymap_vanster"
        case .top:  "bodymap_ovan"
        }
    }

    /// Avkodar en lagrad rå-sträng, inklusive äldre vy-namn.
    /// nonisolated: anropas från SwiftDatas nonisolated model-accessor
    /// (`injuryView`) trots projektets MainActor-standardisolering.
    nonisolated static func decode(_ raw: String) -> BodyView? {
        if let v = BodyView(rawValue: raw) { return v }
        switch raw {
        case "left", "right", "front", "back": return .side
        case "bottom": return .top
        default: return nil
        }
    }
}

/// Läk-status för en skada.
enum HealingStatus: String, Codable, CaseIterable, Identifiable {
    case active, healing, healed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:  String(localized: "Aktiv")
        case .healing: String(localized: "Läker")
        case .healed:  String(localized: "Läkt")
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
        get { injuryViewRaw.flatMap(BodyView.decode) }
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
