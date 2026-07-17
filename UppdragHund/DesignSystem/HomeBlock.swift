//
//  HomeBlock.swift
//  UppdragHund
//
//  Hemskärmens block som flyttbara "widgets": användaren väljer ordning och
//  vilka som visas. Sparas i UserDefaults som kommaseparerade rawValues.
//

import Foundation

enum HomeBlock: String, CaseIterable, Identifiable {
    case dog, today, shortcuts, overview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dog:       "Hundkort"
        case .today:     "Idag"
        case .shortcuts: "Genvägar"
        case .overview:  "Översikt"
        }
    }

    var subtitle: String {
        switch self {
        case .dog:       "Aktiv hund med namn, ras och ålder"
        case .today:     "Dagens att-göra för din hund"
        case .shortcuts: "Snabbknappar till dina favoritdelar"
        case .overview:  "Vikt, motion, hälsa och löp"
        }
    }

    var icon: String {
        switch self {
        case .dog:       "pawprint.fill"
        case .today:     "sun.max.fill"
        case .shortcuts: "square.grid.2x2"
        case .overview:  "chart.bar.xaxis"
        }
    }

    static let defaults: [HomeBlock] = [.dog, .today, .shortcuts, .overview]
}

enum HomeBlockStore {
    static let storageKey = "homeBlocks"

    static func decode(_ raw: String) -> [HomeBlock] {
        raw.split(separator: ",").compactMap { HomeBlock(rawValue: String($0)) }
    }

    static func encode(_ list: [HomeBlock]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }

    static let defaultRaw = encode(HomeBlock.defaults)
}
