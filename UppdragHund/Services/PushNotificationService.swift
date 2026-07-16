//
//  PushNotificationService.swift
//  UppdragHund
//
//  Hanterar notistillstånd och lagring av FCM-token i Firestore under
//  users/{uid}/fcmTokens/{token}. Cloud Functions läser dessa för att skicka
//  push vid nya inlägg, delade hundar och vänförfrågningar.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

final class PushNotificationService {
    static let shared = PushNotificationService()

    private let db = Firestore.firestore()
    private var latestToken: String?
    /// Persistent så avregistrering fungerar även efter appomstart.
    private var lastKnownUid: String? {
        get { UserDefaults.standard.string(forKey: "pushTokenUid") }
        set { UserDefaults.standard.set(newValue, forKey: "pushTokenUid") }
    }

    private init() {}

    /// Ber om tillstånd och registrerar för fjärrnotiser. Anropas efter inloggning.
    @MainActor
    func registerForPushNotifications() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Sparar token under inloggad användare. Ignoreras tyst om ingen är inloggad
    /// (token cachas och sparas senare via `syncTokenAfterSignIn()`).
    func saveToken(_ token: String) async {
        latestToken = token
        guard let uid = AuthService.shared.currentUserID else { return }
        lastKnownUid = uid
        try? await db.collection("users").document(uid)
            .collection("fcmTokens").document(token)
            .setData([
                "token": token,
                "updatedAt": FieldValue.serverTimestamp(),
                "platform": "ios"
            ])
        // Registrera enhetens ägare — servern städar bort token från
        // tidigare konton på samma enhet (Cloud Function onDeviceTokenClaimed).
        try? await db.collection("deviceTokens").document(token)
            .setData(["uid": uid, "updatedAt": FieldValue.serverTimestamp()])
    }

    /// Persistar den senaste kända token under användaren efter inloggning.
    func syncTokenAfterSignIn() async {
        if let token = latestToken {
            await saveToken(token)
        } else if let token = try? await Messaging.messaging().token() {
            await saveToken(token)
        }
    }

    /// Tar bort denna enhets token. MÅSTE anropas FÖRE utloggning —
    /// efter signOut nekar säkerhetsreglerna raderingen.
    func removeToken() async {
        guard let uid = lastKnownUid else { return }
        let token: String?
        if let latestToken {
            token = latestToken
        } else {
            token = try? await Messaging.messaging().token()
        }
        guard let token else { return }
        try? await db.collection("users").document(uid)
            .collection("fcmTokens").document(token).delete()
        try? await db.collection("deviceTokens").document(token).delete()
        lastKnownUid = nil
    }
}
