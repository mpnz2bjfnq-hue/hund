//
//  NotificationService.swift
//  UppdragHund
//

import Foundation
import SwiftData
import UserNotifications

enum NotificationService {
    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    static func triggerDateComponents(for date: Date, calendar: Calendar = .current, hour: Int = 9) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return components
    }

    static func shouldSchedule(predictedStartDate: Date, referenceDate: Date = .now) -> Bool {
        predictedStartDate > referenceDate
    }

    static func identifier(for dog: Dog) -> String {
        "heat-prediction-\(String(describing: dog.persistentModelID))"
    }

    static func scheduleHeatPredictionNotification(
        for dog: Dog,
        predictedStartDate: Date,
        calendar: Calendar = .current,
        daysBefore: Int = 7
    ) async {
        let center = UNUserNotificationCenter.current()
        let id = identifier(for: dog)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        // Fira `daysBefore` dagar före det förväntade löpet, kl. 09:00.
        let fireDate = calendar.date(byAdding: .day, value: -daysBefore, to: predictedStartDate) ?? predictedStartDate
        guard shouldSchedule(predictedStartDate: fireDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Löp närmar sig"
        content.body = "\(dog.name) förväntas börja löpa om \(daysBefore) dagar."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDateComponents(for: fireDate, calendar: calendar),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelHeatPredictionNotification(for dog: Dog) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: dog)])
    }

    // MARK: - Pågående löp ("har löpt i X dagar")

    private static func ongoingHeatIdentifier(for dog: Dog, day: Int) -> String {
        "ongoing-heat-\(String(describing: dog.persistentModelID))-day-\(day)"
    }

    /// Daglig notis under ett pågående löp som räknar antalet dagar. iOS-notiser
    /// har statisk text, så vi lägger en per kommande dag i cykeln.
    static func scheduleOngoingHeatNotifications(
        for dog: Dog,
        cycleStart: Date,
        calendar: Calendar = .current,
        maxDays: Int = 28,
        hour: Int = 9
    ) async {
        let center = UNUserNotificationCenter.current()
        cancelOngoingHeatNotifications(for: dog, maxDays: maxDays)

        let startDay = calendar.startOfDay(for: cycleStart)
        for day in 1...maxDays {
            guard let fireDay = calendar.date(byAdding: .day, value: day, to: startDay) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: fireDay)
            comps.hour = hour
            comps.minute = 0
            guard let fireDate = calendar.date(from: comps), fireDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Löp pågår"
            content.body = "\(dog.name) har löpt i \(day) \(day == 1 ? "dag" : "dagar")."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: ongoingHeatIdentifier(for: dog, day: day),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func cancelOngoingHeatNotifications(for dog: Dog, maxDays: Int = 28) {
        let ids = (1...maxDays).map { ongoingHeatIdentifier(for: dog, day: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Daglig träningspåminnelse

    static let trainingReminderID = "daily-training-reminder"

    /// Återkommande daglig påminnelse om att logga träning.
    static func scheduleDailyTrainingReminder(hour: Int = 12) async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Dags att logga träning 🐾"
        content.body = "Glöm inte att gå in och logga dagens träning och promenader."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: trainingReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelDailyTrainingReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [trainingReminderID])
    }

    // MARK: - Egna påminnelser

    private static func customIdentifier(_ id: UUID) -> String { "user-reminder-\(id.uuidString)" }

    static func scheduleCustomReminder(_ reminder: CustomReminder, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [customIdentifier(reminder.id)])

        let content = UNMutableNotificationContent()
        content.title = "Påminnelse 🐾"
        content.body = reminder.title
        content.sound = .default

        let comps: DateComponents
        switch reminder.repeatRule {
        case .never:
            guard reminder.date > .now else { return }
            comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        case .daily:
            comps = calendar.dateComponents([.hour, .minute], from: reminder.date)
        case .weekly:
            comps = calendar.dateComponents([.weekday, .hour, .minute], from: reminder.date)
        case .monthly:
            comps = calendar.dateComponents([.day, .hour, .minute], from: reminder.date)
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: reminder.repeatRule != .never)
        try? await center.add(UNNotificationRequest(identifier: customIdentifier(reminder.id), content: content, trigger: trigger))
    }

    static func cancelCustomReminder(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [customIdentifier(id)])
    }

    /// Avbokar alla löp-relaterade notiser (prognos + pågående) oavsett hund.
    static func cancelAllHeatNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter {
            $0.hasPrefix("heat-prediction-") || $0.hasPrefix("ongoing-heat-")
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Hälsohändelser / bokade besök

    static func healthEventIdentifier(_ event: HealthEvent) -> String {
        "health-event-\(event.remoteID?.uuidString ?? "\(ObjectIdentifier(event).hashValue)")"
    }

    /// Notis på morgonen för en framtida hälsohändelse (t.ex. bokat vet-besök).
    static func scheduleHealthEventNotification(
        for event: HealthEvent,
        calendar: Calendar = .current,
        hour: Int = 9
    ) async {
        let center = UNUserNotificationCenter.current()
        let id = healthEventIdentifier(event)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard event.date > .now else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: event.date)
        comps.hour = hour
        comps.minute = 0
        guard let fireDate = calendar.date(from: comps), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = event.type.displayName
        content.body = event.title.isEmpty ? "Påminnelse idag." : "\(event.title) idag."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancelHealthEventNotification(for event: HealthEvent) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [healthEventIdentifier(event)]
        )
    }

    // MARK: - Återkommande påminnelser (klippa klor, avmaskning …)

    static func recurringIdentifier(_ id: String) -> String { "recurring-\(id)" }

    /// Återkommande notis var `intervalWeeks` vecka. Använder tidsintervall-trigger
    /// eftersom kalender-triggers inte kan repetera var N:e vecka.
    static func scheduleRecurringReminder(id: String, body: String, intervalWeeks: Int) async {
        let center = UNUserNotificationCenter.current()
        let seconds = TimeInterval(max(1, intervalWeeks) * 7 * 24 * 3600)

        let content = UNMutableNotificationContent()
        content.title = "Påminnelse 🐾"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: recurringIdentifier(id), content: content, trigger: trigger))
    }

    static func cancelRecurringReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [recurringIdentifier(id)]
        )
    }
}
