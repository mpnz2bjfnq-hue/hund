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
    var remoteID: UUID?
    // Synk/delning: nil createdByUid = skapad av hundens ägare på egna enheten.
    var createdByUid: String?
    var createdByName: String?
    var updatedAt: Date?
    var pendingUpload: Bool = false
    var type: MealType
    var time: Date
    var name: String
    var note: String?
    var dog: Dog?

    init(type: MealType, time: Date, name: String, note: String? = nil, dog: Dog? = nil) {
        self.remoteID = UUID()
        self.type = type
        self.time = time
        self.name = name
        self.note = note
        self.dog = dog
    }
}
