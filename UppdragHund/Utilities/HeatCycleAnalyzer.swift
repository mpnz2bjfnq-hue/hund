//
//  HeatCycleAnalyzer.swift
//  UppdragHund
//

import Foundation

enum HeatCycleAnalyzer {
    struct HistoryEntry {
        let cycle: HeatCycle
        let intervalSincePreviousDays: Int?
        let deviationFromPredictedDays: Int?
    }

    static func history(
        from cycles: [HeatCycle],
        breedReference: BreedReference = .genericFallback,
        calendar: Calendar = .current
    ) -> [HistoryEntry] {
        let completed = cycles.filter { !$0.isOngoing }.sorted { $0.startDate < $1.startDate }
        var entries: [HistoryEntry] = []

        for index in completed.indices {
            let cycle = completed[index]

            guard index > 0 else {
                entries.append(HistoryEntry(cycle: cycle, intervalSincePreviousDays: nil, deviationFromPredictedDays: nil))
                continue
            }

            let priorCycles = Array(completed[0..<index])
            // Dygnsnormaliserat, samma skäl som i HeatPredictor.
            let actualInterval = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: priorCycles.last!.startDate),
                to: calendar.startOfDay(for: cycle.startDate)
            ).day ?? 0
            let prediction = HeatPredictor.predict(
                completedCycles: priorCycles,
                breedReference: breedReference,
                calendar: calendar
            )

            entries.append(HistoryEntry(
                cycle: cycle,
                intervalSincePreviousDays: actualInterval,
                deviationFromPredictedDays: actualInterval - prediction.predictedIntervalDays
            ))
        }

        return entries.sorted { $0.cycle.startDate > $1.cycle.startDate }
    }
}
