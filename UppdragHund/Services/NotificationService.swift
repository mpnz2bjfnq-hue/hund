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
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        let id = identifier(for: dog)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard shouldSchedule(predictedStartDate: predictedStartDate) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Förväntat löp snart"
        content.body = "\(dog.name) kan börja löpa runt \(predictedStartDate.formatted(date: .abbreviated, time: .omitted))."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerDateComponents(for: predictedStartDate, calendar: calendar),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func cancelHeatPredictionNotification(for dog: Dog) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: dog)])
    }
}
