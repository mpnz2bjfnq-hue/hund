//
//  SharingDTOs.swift
//  UppdragHund
//
//  Firestore-dokumentformer för delade hundar. Dokument-ID:n sätts explicit
//  från remoteID.uuidString i repository-lagret — DTO:erna bär dem inte själva,
//  så mappningen kan testas utan Firestore-encoder.
//

import Foundation

struct ShareDoc: Codable, Equatable {
    var dogRemoteID: String
    var ownerUid: String
    var ownerDisplayName: String
    var dogName: String
    var recipientUid: String
    var modules: [String]
    var permission: String
    var createdAt: Date
    var updatedAt: Date

    /// Deterministiskt dokument-ID — säkerhetsreglerna slår upp exakt denna sökväg.
    var documentID: String { Self.documentID(dogRemoteID: dogRemoteID, recipientUid: recipientUid) }

    static func documentID(dogRemoteID: String, recipientUid: String) -> String {
        "\(dogRemoteID)_\(recipientUid)"
    }
}

struct SharedDogDoc: Codable, Equatable {
    var ownerUid: String
    var ownerDisplayName: String
    var name: String
    var breed: String
    var birthDate: Date
    var sex: String
    var updatedAt: Date
    // Registrering & identitet. Valfria → gamla dokument utan dem avkodas som nil.
    var color: String? = nil
    var registrationNumber: String? = nil
    var chipNumber: String? = nil
    var breeder: String? = nil
    // Meriter (badges). Valfria av samma bakåtkompatibilitetsskäl.
    var hdResult: String? = nil
    var edResult: String? = nil
    var mentalTestDone: Bool? = nil
    var showMerit: Bool? = nil
    var vaccinated: Bool? = nil
    // Liten JPEG-thumbnail (~256px). Firestore lagrar som Blob; ryms i dokumentet.
    var photoData: Data? = nil
}

struct HealthEventDTO: Codable, Equatable {
    var type: String
    var title: String
    var date: Date
    var note: String?
    var bodyLocation: String?
    var weightKg: Double?
    var temperatureCelsius: Double?
    var createdByUid: String
    var createdByName: String
    var updatedAt: Date
}

struct HeatCycleDTO: Codable, Equatable {
    var startDate: Date
    var endDate: Date?
    var createdByUid: String
    var createdByName: String
    var updatedAt: Date
}

struct DiaryEntryDTO: Codable, Equatable {
    var date: Date
    var bleedingLevel: Int
    var swellingLevel: Int
    var appetiteLevel: Int
    var energyLevel: Int
    var mood: String
    // photoData delas medvetet inte i v1.
    var createdByUid: String
    var createdByName: String
    var updatedAt: Date
}

struct MealEntryDTO: Codable, Equatable {
    var type: String
    var time: Date
    var name: String
    var note: String?
    var createdByUid: String
    var createdByName: String
    var updatedAt: Date
}

struct TrainingSessionDTO: Codable, Equatable {
    var date: Date
    var activity: String
    var durationMinutes: Int?
    var note: String?
    var createdByUid: String
    var createdByName: String
    var updatedAt: Date
}
