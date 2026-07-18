//
//  TrainingSkill.swift
//  UppdragHund
//
//  En färdighet/trick hunden tränar på, med nivå: Ej börjat → På gång → Behärskar.
//

import Foundation
import SwiftData

enum SkillLevel: String, Codable, CaseIterable, Identifiable {
    case notStarted
    case inProgress
    case mastered

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStarted: String(localized: "Ej börjat")
        case .inProgress: String(localized: "På gång")
        case .mastered: String(localized: "Behärskar")
        }
    }

    /// Nästa nivå i cykeln (för att stega med ett tryck).
    var next: SkillLevel {
        switch self {
        case .notStarted: .inProgress
        case .inProgress: .mastered
        case .mastered: .notStarted
        }
    }

    /// 0–3 fyllda punkter för progress-visning.
    var filledDots: Int {
        switch self {
        case .notStarted: 0
        case .inProgress: 2
        case .mastered: 3
        }
    }
}

@Model
final class TrainingSkill {
    var name: String
    var levelRaw: String
    var order: Int
    var createdAt: Date
    var dog: Dog?

    init(name: String, level: SkillLevel = .notStarted, order: Int, dog: Dog? = nil) {
        self.name = name
        self.levelRaw = level.rawValue
        self.order = order
        self.createdAt = .now
        self.dog = dog
    }

    var level: SkillLevel {
        get { SkillLevel(rawValue: levelRaw) ?? .notStarted }
        set { levelRaw = newValue.rawValue }
    }
}
