//
//  HeatPredictor.swift
//  UppdragHund
//

import Foundation

nonisolated enum PredictionBasis: Equatable {
    case breedReference
    case ownHistory
}

struct HeatPrediction: Equatable {
    let predictedIntervalDays: Int
    let predictedDurationDays: Int
    let basis: PredictionBasis
    let learnedFromCycleCount: Int
    let nextExpectedStartDate: Date?
}

enum HeatPredictor {
    static func predict(
        completedCycles: [HeatCycle],
        breedReference: BreedReference,
        calendar: Calendar = .current
    ) -> HeatPrediction {
        let sorted = completedCycles.sorted { $0.startDate < $1.startDate }

        // Dygnsnormaliserat — annars golvas intervallet av klockslagen och
        // prognosen driver en dag beroende på när på dygnet löpen registrerades.
        let intervals: [Int] = zip(sorted, sorted.dropFirst()).map { previous, next in
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: previous.startDate),
                to: calendar.startOfDay(for: next.startDate)
            ).day ?? 0
        }
        let durations = sorted.compactMap(\.durationInDays)

        let basis: PredictionBasis = intervals.isEmpty ? .breedReference : .ownHistory
        let intervalDays = intervals.isEmpty
            ? breedReference.averageCycleIntervalDays
            : intervals.reduce(0, +) / intervals.count
        let durationDays = durations.isEmpty
            ? breedReference.averageCycleDurationDays
            : durations.reduce(0, +) / durations.count

        let nextExpectedStartDate = sorted.last.flatMap {
            calendar.date(byAdding: .day, value: intervalDays, to: $0.startDate)
        }

        return HeatPrediction(
            predictedIntervalDays: intervalDays,
            predictedDurationDays: durationDays,
            basis: basis,
            learnedFromCycleCount: intervals.count,
            nextExpectedStartDate: nextExpectedStartDate
        )
    }
}
