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

    // Notistryck → djuplänk. Cloud Functions skickar redan med ett `type` och
    // ett id i data-payloaden; här översätts det till en canine360://-URL som
    // MainTabView routar (samma väg som widgetarnas länkar).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let url = PushRoute.deepLink(for: info) else { return }
        await MainActor.run { DeepLinkStore.shared.pending = url }
    }
}

// MARK: - Notis → djuplänk

enum PushRoute {
    /// Översätter FCM-payloadens `type` (+ tillhörande id) till en djuplänk.
    /// Returnerar nil för notiser utan egen destination — då öppnas appen bara.
    static func deepLink(for userInfo: [AnyHashable: Any]) -> URL? {
        guard let type = userInfo["type"] as? String else { return nil }
        let scheme = WidgetDeepLink.scheme

        func string(_ key: String) -> String? {
            guard let value = userInfo[key] as? String, !value.isEmpty else { return nil }
            return value
        }

        switch type {
        case "teamInvite", "teamPost", "teamTask", "teamMemberJoined":
            guard let id = string("teamId") else { return nil }
            return URL(string: "\(scheme)://team?id=\(id)")
        case "meetup":
            guard let id = string("meetupId") else { return nil }
            return URL(string: "\(scheme)://meetup?id=\(id)")
        case "friendRequest":
            return URL(string: "\(scheme)://vanner")
        case "post":
            return URL(string: "\(scheme)://socialt")
        case "share":
            return URL(string: "\(scheme)://hem")
        default:
            return nil
        }
    }
}
