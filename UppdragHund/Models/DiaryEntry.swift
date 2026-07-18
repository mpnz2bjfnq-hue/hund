//
//  DiaryEntry.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum DiaryMood: String, Codable, CaseIterable, Identifiable {
    case great
    case good
    case neutral
    case bad
    case terrible

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .great: "😄"
        case .good: "🙂"
        case .neutral: "😐"
        case .bad: "😟"
        case .terrible: "🤒"
        }
    }

    var displayName: String {
        switch self {
        case .great: String(localized: "Mycket bra")
        case .good: String(localized: "Bra")
        case .neutral: String(localized: "Okej")
        case .bad: String(localized: "Dålig")
        case .terrible: String(localized: "Mycket dålig")
        }
    }
}

@Model
final class DiaryEntry {
    var remoteID: UUID?
    // Synk/delning: nil createdByUid = skapad av hundens ägare på egna enheten.
    var createdByUid: String?
    var createdByName: String?
    var updatedAt: Date?
    var pendingUpload: Bool = false
    var date: Date
    var bleedingLevel: Int
    var swellingLevel: Int
    var appetiteLevel: Int
    var energyLevel: Int
    var mood: DiaryMood

    @Attribute(.externalStorage)
    var photoData: Data?

    var dog: Dog?

    init(
        date: Date,
        bleedingLevel: Int = 0,
        swellingLevel: Int = 0,
        appetiteLevel: Int = 3,
        energyLevel: Int = 3,
        mood: DiaryMood = .neutral,
        photoData: Data? = nil,
        dog: Dog? = nil
    ) {
        self.remoteID = UUID()
        self.date = date
        self.bleedingLevel = bleedingLevel
        self.swellingLevel = swellingLevel
        self.appetiteLevel = appetiteLevel
        self.energyLevel = energyLevel
        self.mood = mood
        self.photoData = photoData
        self.dog = dog
    }
}
