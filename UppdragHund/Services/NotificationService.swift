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
        content.title = String(localized: "Löp närmar sig")
        content.body = String(localized: "\(dog.name) förväntas börja löpa om \(daysBefore) dagar.")
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

    // MARK: - Pågående löp

    private static func ongoingHeatIdentifier(for dog: Dog, day: Int) -> String {
        "ongoing-heat-\(String(describing: dog.persistentModelID))-day-\(day)"
    }

    /// Notiser under ett pågående löp — bara på de dagar som bär ett beslut
    /// (boka provet, ta provet, och till sist en fråga om ett löp som blivit
    /// liggande). Se HeatGuide.nudges. iOS-notiser har statisk text, så varje
    /// dag schemaläggs som en egen notis.
    static func scheduleOngoingHeatNotifications(
        for dog: Dog,
        cycleStart: Date,
        calendar: Calendar = .current,
        hour: Int = 9
    ) async {
        let center = UNUserNotificationCenter.current()
        cancelOngoingHeatNotifications(for: dog)

        let startDay = calendar.startOfDay(for: cycleStart)
        for nudge in HeatGuide.nudges(dogName: dog.name) {
            // Dag 1 = startdagen, så dag N ligger N-1 dygn efter start.
            guard let fireDay = calendar.date(byAdding: .day, value: nudge.day - 1, to: startDay) else { continue }
            let comps = triggerDateComponents(for: fireDay, calendar: calendar, hour: hour)
            guard let fireDate = calendar.date(from: comps), fireDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = nudge.title
            content.body = nudge.body
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: ongoingHeatIdentifier(for: dog, day: nudge.day),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Städar hela det historiska dagsspannet, inte bara dagens notis-dagar —
    /// annars ligger den gamla dagliga räknaren kvar i befintliga
    /// installationer och fortsätter avfyras varje morgon.
    static func cancelOngoingHeatNotifications(for dog: Dog) {
        let ids = HeatGuide.notificationDayRange.map { ongoingHeatIdentifier(for: dog, day: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Försäkringsförnyelse

    static func insuranceRenewalIdentifier(for dog: Dog) -> String {
        "insurance-renewal-\(String(describing: dog.persistentModelID))"
    }

    /// Notis 14 dagar före försäkringens förnyelsedatum (kl. 09:00) — hinner
    /// jämföra pris/byta bolag. Är förnyelsen närmare än så notifieras
    /// morgonen på förnyelsedagen i stället. Tar bort notisen om datumet
    /// rensats.
    static func scheduleInsuranceRenewalNotification(
        for dog: Dog,
        calendar: Calendar = .current,
        daysBefore: Int = 14
    ) async {
        let center = UNUserNotificationCenter.current()
        let id = insuranceRenewalIdentifier(for: dog)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        // Änglar behöver ingen påminnelse — försäkringen är rimligen avslutad.
        guard let renewal = dog.insuranceRenewalDate, !dog.isDeceased else { return }
        let early = calendar.date(byAdding: .day, value: -daysBefore, to: renewal) ?? renewal
        let fireDay = early > .now ? early : renewal
        let comps = triggerDateComponents(for: fireDay, calendar: calendar)
        guard let fireDate = calendar.date(from: comps), fireDate > .now else { return }
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Försäkringen förnyas snart")
        if let company = dog.insuranceCompany, !company.isEmpty {
            content.body = String(localized: "\(dog.name)s försäkring hos \(company) förnyas \(renewal.formatted(date: .abbreviated, time: .omitted)). Bra läge att se över den.")
        } else {
            content.body = String(localized: "\(dog.name)s försäkring förnyas \(renewal.formatted(date: .abbreviated, time: .omitted)). Bra läge att se över den.")
        }
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancelInsuranceRenewalNotification(for dog: Dog) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [insuranceRenewalIdentifier(for: dog)]
        )
    }

    /// Självläkande svep vid inloggning: schemat lever inte i molnbackupen,
    /// så efter en återställning/ominstallation byggs notiserna upp igen här.
    static func syncInsuranceRenewalReminders(dogs: [Dog]) async {
        for dog in dogs where !dog.isShared {
            await scheduleInsuranceRenewalNotification(for: dog)
        }
    }

    /// Avbokar ALLA notiser knutna till en hund (löpprognos, pågående löp,
    /// försäkring, hälsohändelser). Anropas när hunden försvinner — radering,
    /// återkallad delning — eftersom identifierarna inte går att återskapa
    /// när objektet väl är borta.
    static func cancelAllNotifications(for dog: Dog) {
        cancelHeatPredictionNotification(for: dog)
        cancelOngoingHeatNotifications(for: dog)
        cancelInsuranceRenewalNotification(for: dog)
        for event in dog.healthEvents {
            cancelHealthEventNotification(for: event)
        }
    }

    /// Löpnotis-svep vid inloggning (samma logik som KalenderView, som annars
    /// bara läker när fliken öppnas): prognosnotis + pågående-löp-notiser för
    /// alla egna tikar. Respekterar löppåminnelse-inställningen.
    static func syncHeatReminders(dogs: [Dog]) async {
        guard UserDefaults.standard.object(forKey: "heatRemindersEnabled") as? Bool ?? true else { return }
        for dog in dogs where !dog.isShared && dog.tracksHeat {
            let completed = dog.heatCycles.filter { !$0.isOngoing }
            let reference = BreedDataService.shared.reference(forBreed: dog.breed)
            let prediction = HeatPredictor.predict(completedCycles: completed, breedReference: reference)
            if let nextStart = prediction.nextExpectedStartDate {
                await scheduleHeatPredictionNotification(for: dog, predictedStartDate: nextStart)
            }
            if let ongoing = dog.heatCycles.first(where: { $0.isOngoing }) {
                await scheduleOngoingHeatNotifications(for: dog, cycleStart: ongoing.startDate)
            }
        }
    }

    // MARK: - Daglig träningspåminnelse

    static let trainingReminderID = "daily-training-reminder"

    /// Återkommande daglig påminnelse om att logga träning.
    static func scheduleDailyTrainingReminder(hour: Int = 12) async {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dags att logga träning 🐾")
        content.body = String(localized: "Glöm inte att gå in och logga dagens träning och promenader.")
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

    /// nil när remoteID saknas — ett ObjectIdentifier-baserat fallback-id vore
    /// olika per applansering och skulle ge oavbokbara dubblettnotiser.
    static func healthEventIdentifier(_ event: HealthEvent) -> String? {
        event.remoteID.map { "health-event-\($0.uuidString)" }
    }

    /// Notis på morgonen för en framtida hälsohändelse (t.ex. bokat vet-besök).
    static func scheduleHealthEventNotification(
        for event: HealthEvent,
        calendar: Calendar = .current,
        hour: Int = 9
    ) async {
        guard let id = healthEventIdentifier(event) else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard event.date > .now else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: event.date)
        comps.hour = hour
        comps.minute = 0
        guard let fireDate = calendar.date(from: comps), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = event.type.displayName
        content.body = event.title.isEmpty ? String(localized: "Påminnelse idag.") : String(localized: "\(event.title) idag.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancelHealthEventNotification(for event: HealthEvent) {
        guard let id = healthEventIdentifier(event) else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id]
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

    // MARK: - Träffpåminnelser (1 timme innan)

    private static let meetupReminderPrefix = "meetup-reminder-"

    /// Synkar lokala påminnelser mot mina kommande träffar: en notis 1 timme
    /// innan varje träff jag ordnar eller tackat ja till. Rensar först alla
    /// gamla träffpåminnelser så ändrade tider, avböjda svar och inställda
    /// träffar hanteras automatiskt.
    static func syncMeetupReminders(for uid: String) async {
        let meetups = await TeamsRepository.shared.upcomingMeetups(uid: uid)
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(meetupReminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let attending = meetups.filter { $0.ownerUid == uid || $0.goingUids.contains(uid) }
        guard !attending.isEmpty, await requestAuthorizationIfNeeded() else { return }

        for meetup in attending {
            guard let id = meetup.id else { continue }
            let fireDate = meetup.date.addingTimeInterval(-3600)
            guard fireDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Snart träff: \(meetup.title)")
            content.body = String(localized: "\(meetup.locationName) · kl \(meetup.date.formatted(date: .omitted, time: .shortened))")
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: meetupReminderPrefix + id,
                content: content,
                trigger: trigger
            ))
        }
    }
}
