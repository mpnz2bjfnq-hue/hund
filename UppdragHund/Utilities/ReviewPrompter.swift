//
//  ReviewPrompter.swift
//  UppdragHund
//
//  Betyg i App Store: dels den diskreta systemdialogen (Apple-throttlad,
//  max ~3 ggr/år) som visas efter några lyckade loggningar, dels länken
//  till "Skriv en recension" för Betygsätt-knappen i Min profil.
//

import Foundation
import StoreKit
import UIKit

enum ReviewPrompter {
    /// Appens numeriska App Store-ID (App Store Connect → Appinformation).
    static let appStoreID = "6790578115"

    /// Produktsidan med recensionsformuläret öppnat.
    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    /// Produktsidan — för "Dela appen".
    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    }

    private static let eventCountKey = "review.meaningfulEventCount"
    private static let promptedVersionKey = "review.lastPromptedVersion"
    /// Antal lyckade loggningar innan frågan ställs — användaren ska ha
    /// hunnit få ut något av appen innan vi ber om betyg.
    private static let threshold = 3

    /// Registrera ett "bra ögonblick" (sparad promenad/hälsopost/pass …).
    /// Efter tre sådana visas Apples betygsdialog — max en gång per
    /// appversion, och bara om systemet självt tycker att det passar
    /// (Apple throttlar hårt, så anropet är alltid säkert).
    @MainActor
    static func registerMeaningfulEvent() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: eventCountKey) + 1
        defaults.set(count, forKey: eventCountKey)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard count >= threshold,
              defaults.string(forKey: promptedVersionKey) != version,
              let scene = UIApplication.shared.connectedScenes
                  .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        defaults.set(version, forKey: promptedVersionKey)
        AppStore.requestReview(in: scene)
    }
}
