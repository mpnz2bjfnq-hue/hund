//
//  RecurringReminder.swift
//  UppdragHund
//
//  Återkommande skötselpåminnelser (klippa klor, avmaskning …) med valbart
//  intervall. Lagras som JSON i UserDefaults.
//

import Foundation

struct RecurringReminder: Codable, Identifiable, Equatable {
    var id: String        // stabil nyckel, t.ex. "nails"
    var title: String     // "Klippa klor"
    var body: String      // "Dags att klippa klorna."
    var isEnabled: Bool
    var intervalWeeks: Int
}

// MARK: - Egna påminnelser (skapade av användaren)

enum ReminderRepeat: String, Codable, CaseIterable, Identifiable {
    case never, daily, weekly, monthly

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .never:   "Aldrig"
        case .daily:   "Varje dag"
        case .weekly:  "Varje vecka"
        case .monthly: "Varje månad"
        }
    }
}

struct CustomReminder: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var date: Date
    var repeatRule: ReminderRepeat

    var scheduleDescription: String {
        switch repeatRule {
        case .never:
            return date.formatted(date: .abbreviated, time: .shortened)
        case .daily:
            return "Varje dag kl. \(date.formatted(date: .omitted, time: .shortened))"
        case .weekly:
            let weekday = date.formatted(.dateTime.weekday(.wide))
            return "Varje \(weekday) kl. \(date.formatted(date: .omitted, time: .shortened))"
        case .monthly:
            let day = Calendar.current.component(.day, from: date)
            return "Den \(day):e varje månad kl. \(date.formatted(date: .omitted, time: .shortened))"
        }
    }
}

enum CustomReminderStore {
    static let key = "customReminders"

    static func load() -> [CustomReminder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([CustomReminder].self, from: data) else {
            return []
        }
        return list
    }

    static func save(_ list: [CustomReminder]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum RecurringReminderStore {
    static let key = "recurringReminders"

    static let defaults: [RecurringReminder] = [
        .init(id: "nails",  title: "Klippa klor",  body: "Dags att klippa klorna.",   isEnabled: false, intervalWeeks: 3),
        .init(id: "deworm", title: "Avmaskning",   body: "Dags för avmaskning.",       isEnabled: false, intervalWeeks: 12),
        .init(id: "tick",   title: "Fästingmedel", body: "Dags att ge fästingmedel.",  isEnabled: false, intervalWeeks: 4),
        .init(id: "bath",   title: "Bad",          body: "Dags för ett bad.",          isEnabled: false, intervalWeeks: 8),
    ]

    static func load() -> [RecurringReminder] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([RecurringReminder].self, from: data),
              !list.isEmpty else {
            return defaults
        }
        return list
    }

    static func save(_ list: [RecurringReminder]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
