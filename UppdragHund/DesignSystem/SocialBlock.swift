//
//  SocialBlock.swift
//  UppdragHund
//
//  Socialt-flikens block som flyttbara "widgets": användaren väljer ordning
//  och vilka som visas. Samma mönster som HomeBlock — sparas i UserDefaults
//  som kommaseparerade rawValues.
//

import Foundation

enum SocialBlock: String, CaseIterable, Identifiable {
    case teams, discover, meetups, forum

    var id: String { rawValue }

    var title: String {
        switch self {
        case .teams:    "Dina team & grupper"
        case .discover: "Gå med i nytt"
        case .meetups:  "Träffar"
        case .forum:    "Forum"
        }
    }

    var subtitle: String {
        switch self {
        case .teams:    "Teamen och stadsgrupperna du är med i"
        case .discover: "Skapa team, gå med med kod eller i en stadsgrupp"
        case .meetups:  "Kommande hundträffar"
        case .forum:    "Frågor och diskussion om hundträning"
        }
    }

    var icon: String {
        switch self {
        case .teams:    "person.3.fill"
        case .discover: "plus.circle.fill"
        case .meetups:  "calendar"
        case .forum:    "bubble.left.and.bubble.right.fill"
        }
    }

    static let defaults: [SocialBlock] = [.teams, .discover, .meetups, .forum]
}

enum SocialBlockStore {
    static let storageKey = "socialBlocks"

    static func decode(_ raw: String) -> [SocialBlock] {
        raw.split(separator: ",").compactMap { SocialBlock(rawValue: String($0)) }
    }

    static func encode(_ list: [SocialBlock]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }

    static let defaultRaw = encode(SocialBlock.defaults)
}
