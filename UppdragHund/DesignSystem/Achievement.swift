//
//  Achievement.swift
//  UppdragHund
//
//  Streak-beräkning och utmärkelser baserade på hundens lokala data.
//

import Foundation

/// Räknar nuvarande streak av på varandra följande dagar med aktivitet.
enum StreakCalculator {
    static func currentStreak(dates: [Date], calendar: Calendar = .current, asOf: Date = .now) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: asOf)
        // Ingen aktivitet idag? Streaken kan ändå gälla t.o.m. igår.
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
            if !days.contains(day) { return 0 }
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

/// Sammanräknad statistik för en hund, använd av utmärkelserna.
struct DogStats {
    let trainingCount: Int
    let trainingMinutes: Int
    let diaryCount: Int
    let mealCount: Int
    let weighingCount: Int
    let trainingStreak: Int

    init(dog: Dog, calendar: Calendar = .current, asOf: Date = .now) {
        trainingCount = dog.trainingSessions.count
        trainingMinutes = dog.trainingSessions.compactMap(\.durationMinutes).reduce(0, +)
        diaryCount = dog.diaryEntries.count
        mealCount = dog.mealEntries.count
        weighingCount = dog.healthEvents.filter { $0.type == .weighing }.count
        trainingStreak = StreakCalculator.currentStreak(
            dates: dog.trainingSessions.map(\.date), calendar: calendar, asOf: asOf
        )
    }
}

enum Achievement: String, CaseIterable, Identifiable {
    case firstTraining, tenTrainings, fiftyTrainings, hundredTrainings
    case thousandMinutes
    case streak3, streak7, streak30
    case diary10, weigh5, meals25

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstTraining:   "Första passet"
        case .tenTrainings:    "10 pass"
        case .fiftyTrainings:  "50 pass"
        case .hundredTrainings: "100 pass"
        case .thousandMinutes: "1000 minuter"
        case .streak3:         "3 dagar i rad"
        case .streak7:         "7 dagar i rad"
        case .streak30:        "30 dagar i rad"
        case .diary10:         "10 dagboksinlägg"
        case .weigh5:          "5 vägningar"
        case .meals25:         "25 måltider"
        }
    }

    var icon: String {
        switch self {
        case .firstTraining:   "figure.run"
        case .tenTrainings:    "figure.run"
        case .fiftyTrainings:  "figure.run.circle.fill"
        case .hundredTrainings: "rosette"
        case .thousandMinutes: "stopwatch.fill"
        case .streak3, .streak7, .streak30: "flame.fill"
        case .diary10:         "book.fill"
        case .weigh5:          "scalemass.fill"
        case .meals25:         "fork.knife"
        }
    }

    var target: Int {
        switch self {
        case .firstTraining:   1
        case .tenTrainings:    10
        case .fiftyTrainings:  50
        case .hundredTrainings: 100
        case .thousandMinutes: 1000
        case .streak3:         3
        case .streak7:         7
        case .streak30:        30
        case .diary10:         10
        case .weigh5:          5
        case .meals25:         25
        }
    }

    func current(for stats: DogStats) -> Int {
        switch self {
        case .firstTraining, .tenTrainings, .fiftyTrainings, .hundredTrainings:
            stats.trainingCount
        case .thousandMinutes:
            stats.trainingMinutes
        case .streak3, .streak7, .streak30:
            stats.trainingStreak
        case .diary10:
            stats.diaryCount
        case .weigh5:
            stats.weighingCount
        case .meals25:
            stats.mealCount
        }
    }

    func isUnlocked(for stats: DogStats) -> Bool {
        current(for: stats) >= target
    }
}
