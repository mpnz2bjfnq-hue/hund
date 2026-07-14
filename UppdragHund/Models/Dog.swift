//
//  Dog.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum DogSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: "Tik"
        case .male: "Hane"
        }
    }
}

@Model
final class Dog {
    // Optional with launch-time backfill: a non-optional default would give every
    // pre-existing row the same UUID during lightweight migration.
    var remoteID: UUID?
    var name: String
    var breed: String
    var birthDate: Date
    var sex: DogSex
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HealthEvent.dog)
    var healthEvents: [HealthEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \HeatCycle.dog)
    var heatCycles: [HeatCycle] = []

    @Relationship(deleteRule: .cascade, inverse: \DiaryEntry.dog)
    var diaryEntries: [DiaryEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \MealEntry.dog)
    var mealEntries: [MealEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \TrainingSession.dog)
    var trainingSessions: [TrainingSession] = []

    init(name: String, breed: String, birthDate: Date, sex: DogSex) {
        self.remoteID = UUID()
        self.name = name
        self.breed = breed
        self.birthDate = birthDate
        self.sex = sex
        self.createdAt = .now
    }
}
