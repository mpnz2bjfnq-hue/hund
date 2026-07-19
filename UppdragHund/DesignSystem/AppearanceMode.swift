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
}
