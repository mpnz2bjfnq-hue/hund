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
        case .great: "Mycket bra"
        case .good: "Bra"
        case .neutral: "Okej"
        case .bad: "Dålig"
        case .terrible: "Mycket dålig"
        }
    }
}

@Model
final class DiaryEntry {
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
