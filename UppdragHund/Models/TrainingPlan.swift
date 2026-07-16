//
//  TrainingPlan.swift
//  UppdragHund
//
//  Ett återanvändbart träningspass (mall): titel + ordnad lista övningar.
//  Inte bundet till en specifik hund – körs med den aktiva hunden och loggar
//  då en TrainingSession. Delning läggs till i senare steg.
//

import Foundation
import SwiftData

@Model
final class TrainingPlan {
    var remoteID: UUID?
    var title: String
    var note: String?
    var createdAt: Date
    // Vem som skapade passet (för framtida delning).
    var authorUid: String?
    var authorName: String?

    @Relationship(deleteRule: .cascade, inverse: \TrainingPlanExercise.plan)
    var exercises: [TrainingPlanExercise] = []

    init(
        title: String,
        note: String? = nil,
        createdAt: Date = .now,
        authorUid: String? = nil,
        authorName: String? = nil
    ) {
        self.remoteID = UUID()
        self.title = title
        self.note = note
        self.createdAt = createdAt
        self.authorUid = authorUid
        self.authorName = authorName
    }

    var sortedExercises: [TrainingPlanExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    /// Ungefärlig total längd i minuter (summan av övningarnas mål-minuter).
    var totalMinutes: Int {
        exercises.compactMap(\.targetMinutes).reduce(0, +)
    }
}

// MARK: - Delbart pass (bäddas in i ett flödesinlägg)

struct SharedTrainingPlan: Codable, Equatable {
    var title: String
    var note: String?
    var exercises: [SharedTrainingExercise]

    var summaryLine: String {
        let minutes = exercises.compactMap(\.targetMinutes).reduce(0, +)
        return "\(exercises.count) övningar · ca \(minutes) min"
    }
}

struct SharedTrainingExercise: Codable, Equatable, Identifiable {
    var id: String { name + (goalDescription) }
    var name: String
    var targetMinutes: Int?
    var reps: Int?
    var targetMeters: Int?
    var instruction: String?

    var goalDescription: String {
        if let targetMinutes { return "\(targetMinutes) min" }
        if let reps { return "\(reps) reps" }
        if let targetMeters { return "\(targetMeters) m" }
        return ""
    }
}

extension TrainingPlan {
    func asShared() -> SharedTrainingPlan {
        SharedTrainingPlan(
            title: title,
            note: note,
            exercises: sortedExercises.map {
                SharedTrainingExercise(name: $0.name, targetMinutes: $0.targetMinutes, reps: $0.reps, targetMeters: $0.targetMeters, instruction: $0.instruction)
            }
        )
    }

    var summaryLine: String {
        "\(exercises.count) övningar · ca \(totalMinutes) min"
    }
}

enum ExerciseGoal: String, Codable, CaseIterable, Identifiable {
    case minutes
    case reps
    case meters

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .minutes: "Min"
        case .reps: "Antal"
        case .meters: "Meter"
        }
    }

    /// Rimligt startvärde när man byter måltyp.
    var defaultValue: Int {
        switch self {
        case .minutes: 5
        case .reps: 10
        case .meters: 100
        }
    }
}

@Model
final class TrainingPlanExercise {
    var name: String
    /// TrainingActivityType.rawValue om övningen kopplas till en fördefinierad typ.
    var activityRaw: String?
    var targetMinutes: Int?
    var reps: Int?
    var targetMeters: Int?
    var instruction: String?
    var order: Int
    var plan: TrainingPlan?

    init(
        name: String,
        activityRaw: String? = nil,
        targetMinutes: Int? = nil,
        reps: Int? = nil,
        targetMeters: Int? = nil,
        instruction: String? = nil,
        order: Int
    ) {
        self.name = name
        self.activityRaw = activityRaw
        self.targetMinutes = targetMinutes
        self.reps = reps
        self.targetMeters = targetMeters
        self.instruction = instruction
        self.order = order
    }

    var goalDescription: String {
        if let targetMinutes { return "\(targetMinutes) min" }
        if let reps { return "\(reps) reps" }
        if let targetMeters { return "\(targetMeters) m" }
        return ""
    }
}
