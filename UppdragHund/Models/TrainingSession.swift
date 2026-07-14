//
//  TrainingSession.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum TrainingActivityType: String, Codable, CaseIterable, Identifiable {
    case recall
    case heel
    case sitDownStay
    case retrieving
    case noseWork
    case agility
    case puppyClass
    case obedience
    case socialization

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recall: "Inkallning"
        case .heel: "Fot"
        case .sitDownStay: "Sitt/Ligg/Stanna"
        case .retrieving: "Apportering"
        case .noseWork: "Sök"
        case .agility: "Agility"
        case .puppyClass: "Valpkurs"
        case .obedience: "Lydnad"
        case .socialization: "Socialisering"
        }
    }
}

@Model
final class TrainingSession {
    var date: Date
    var activity: String
    var durationMinutes: Int?
    var note: String?
    var dog: Dog?

    init(
        date: Date,
        activity: String,
        durationMinutes: Int? = nil,
        note: String? = nil,
        dog: Dog? = nil
    ) {
        self.date = date
        self.activity = activity
        self.durationMinutes = durationMinutes
        self.note = note
        self.dog = dog
    }
}
