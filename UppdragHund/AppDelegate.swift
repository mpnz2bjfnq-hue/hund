//
//  AppDelegate.swift
//  UppdragHund
//
//  Kopplar upp push-notiser: APNs-registrering, FCM-token och visning av
//  notiser i förgrunden. FirebaseApp.configure() sker i UppdragHundApp.init().
//

import UIKit
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Pusharna sätter badge (aps.badge = 1) — nollställ varje gång appen
    // öppnas, annars ligger siffran kvar på ikonen för alltid.
    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
    }

    // APNs-token → skicka vidare till Firebase Messaging.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs-registrering misslyckades: \(error.localizedDescription)")
    }
}

// MARK: - FCM-token

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { await PushNotificationService.shared.saveToken(fcmToken) }
    }
}

// MARK: - Visning & tryck

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Visa notiser även när appen är i förgrunden.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    // Plats för framtida djuplänkning när användaren trycker på en notis.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // TODO: navigera till rätt vy (flöde, delad hund, vänförfrågan).
    }
}
