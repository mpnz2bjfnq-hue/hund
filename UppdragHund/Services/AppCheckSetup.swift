//
//  AppCheckSetup.swift
//  UppdragHund
//
//  Firebase App Check: intygar att anropen kommer från den riktiga appen
//  (Apples App Attest) och inte från skript med den publika API-nyckeln.
//  OBS: att bara skicka intyg är ofarligt — spärren aktiveras först när
//  enforcement slås på per produkt i Firebase-konsolen, och det ska inte
//  göras förrän alla testare kör en build med detta inbyggt.
//

import Foundation
import FirebaseCore
import FirebaseAppCheck

final class Canine360AppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        // Debugbyggen (simulator/devicectl) kan inte göra App Attest —
        // debug-providern ger en token som godkänns via konsolens
        // App Check → Debug tokens.
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }

    /// Måste anropas FÖRE FirebaseApp.configure().
    static func activate() {
        AppCheck.setAppCheckProviderFactory(Canine360AppCheckFactory())
    }
}
