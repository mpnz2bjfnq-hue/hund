//
//  HealthKitService.swift
//  UppdragHund
//
//  Läser promenader/löppass från Apple Hälsa så att träning gjord med
//  Garmin, Apple Watch eller telefonen kan importeras som TrainingSession.
//  Garmin Connect synkar sina aktiviteter till Apple Hälsa, så en direkt
//  Garmin-koppling behövs inte — Hälsa är den gemensamma hubben.
//

import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    /// En importerbar aktivitet läst ur Apple Hälsa.
    struct Workout: Identifiable {
        let id: String            // HKWorkout.uuid
        let date: Date
        let durationMinutes: Int
        let distanceMeters: Double?
        let steps: Int?
        let activityName: String  // "Promenad", "Löpning" …
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        return types
    }

    /// Ber om läsbehörighet. Apple visar aldrig om användaren nekat läsning
    /// (integritet) — vi upptäcker det genom att en tom lista kommer tillbaka.
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Hämtar gång-/löp-/vandringspass från de senaste `days` dagarna, nyast
    /// först. Andra aktivitetstyper (cykel, gym …) hoppas över — det är
    /// hundpromenader vi vill fånga.
    func recentWalks(days: Int = 30) async throws -> [Workout] {
        guard isAvailable else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let walkingType = HKWorkoutActivityType.walking
        let runningType = HKWorkoutActivityType.running
        let hikingType = HKWorkoutActivityType.hiking

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 100,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let all = (samples as? [HKWorkout]) ?? []
                let walks = all.filter {
                    [walkingType, runningType, hikingType].contains($0.workoutActivityType)
                }
                continuation.resume(returning: walks)
            }
            store.execute(query)
        }

        return workouts.map { workout in
            let meters = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter())
            let steps = workout.statistics(for: HKQuantityType(.stepCount))?
                .sumQuantity()?.doubleValue(for: .count())
            return Workout(
                id: workout.uuid.uuidString,
                date: workout.startDate,
                durationMinutes: max(1, Int((workout.duration / 60).rounded())),
                distanceMeters: meters,
                steps: steps.map { Int($0) },
                activityName: Self.name(for: workout.workoutActivityType)
            )
        }
    }

    private static func name(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: String(localized: "Löpning")
        case .hiking: String(localized: "Vandring")
        default: String(localized: "Promenad")
        }
    }
}
