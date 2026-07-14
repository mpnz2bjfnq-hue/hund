//
//  MealEntry.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case meal
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meal: "Måltid"
        case .snack: "Snack/Godis"
        }
    }

    var systemImage: String {
        switch self {
        case .meal: "fork.knife"
        case .snack: "pawprint.fill"
        }
    }
}

@Model
final class MealEntry {
    var type: MealType
    var time: Date
    var name: String
    var note: String?
    var dog: Dog?

    init(type: MealType, time: Date, name: String, note: String? = nil, dog: Dog? = nil) {
        self.type = type
        self.time = time
        self.name = name
        self.note = note
        self.dog = dog
    }
}
