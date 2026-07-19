//
//  AppearanceMode.swift
//  UppdragHund
//
//  Användarens val av färgläge. Sparas i UserDefaults och appliceras på
//  rot-vyn. Standard är att följa systemet (Apples rekommendation) — då
//  följer appen telefonens automatiska ljus/mörkt-schema.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Ljust")
        case .dark: String(localized: "Mörkt")
        }
    }

    var icon: String {
        switch self {
        case .system: "iphone"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    /// nil = följ systemet.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Sätter läget på själva fönstret i stället för via SwiftUI:s
    /// `preferredColorScheme`. Skälet: preferredColorScheme på rotvyn river och
    /// bygger om HELA vytärdet vid varje byte — står man då i en pushad vy
    /// (t.ex. Inställningar) kan navigeringen hänga sig. Med
    /// overrideUserInterfaceStyle sköter UIKit övergången och SwiftUI plockar
    /// bara upp den nya colorScheme ur miljön.
    @MainActor
    private static var pendingApply: DispatchWorkItem?

    @MainActor
    static func apply(_ raw: String) {
        let mode = AppearanceMode(rawValue: raw) ?? .system
        let style = mode.interfaceStyle

        // Slå ihop snabba byten. Varje ändring av overrideUserInterfaceStyle
        // startar en trait-övergång där UIKit snapshottar hela fönstret och
        // tonar över. Växlar man fram och tillbaka snabbare än övergångarna
        // hinner bli klara staplas de på varandra, huvudtråden mättas och
        // watchdogen dödar appen. Bara det sista valet i en snabb serie
        // appliceras; fördröjningen är omärklig vid ett enstaka tryck.
        //
        // Att gå via kön löser också ett andra problem: anropas detta direkt
        // ur .onChange sker mutationen mitt i SwiftUI:s uppdateringspass, och
        // trait-ändringen får då SwiftUI att gå in i sig självt igen.
        pendingApply?.cancel()
        let work = DispatchWorkItem {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    guard window.overrideUserInterfaceStyle != style else { continue }
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
        pendingApply = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
