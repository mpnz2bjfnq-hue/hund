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
    // Färdigheter/trick (namn + nivå). Bäddas i hunddokumentet — få per hund och
    // små, så ingen egen subkollektion behövs. Valfri → äldre dokument avkodas nil.
    var skills: [SharedSkill]? = nil
}

/// En färdighet/trick för molnbackup. Del av SharedDogDoc.skills.
struct SharedSkill: Codable, Equatable {
    var name: String
    var levelRaw: String
    var order: Int
    var createdAt: Date
}

/// Träningspass-mall (bibliotek) för molnbackup. Inte bunden till en hund, så
/// den lagras privat under userBackups/{uid}/trainingPlans/{planId}.
struct TrainingPlanDTO: Codable, Equatable {
    var title: String
    var note: String?
    var createdAt: Date
    var authorUid: String?
    var authorName: String?
    var exercises: [TrainingPlanExerciseDTO]
}

struct TrainingPlanExerciseDTO: Codable, Equatable {
    var name: String
    var activityRaw: String?
    var targetMinutes: Int?
    var reps: Int?
    var targetMeters: Int?
    var instruction: String?
    var order: Int
}

struct HealthEventDTO: Codable, Equatable {
    var type: String
    var title: String
    var date: Date
    var note: String?
    var bodyLocation: String?
    var weightKg: Double?
    var temperatureCelsius: Double?
    // Skademarkör på kroppskartan. Valfria → äldre dokument avkodas som nil.
    var injuryViewRaw: String? = nil
    var injuryX: Double? = nil
    var injuryY: Double? = nil
    var injuryStatusRaw: String? = nil
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
    // Dagboksfoto (komprimerad JPEG ≤ ~600 KB, ryms i dokumentet). Valfri →
    // äldre dokument utan foto avkodas som nil.
    var photoData: Data? = nil
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
    // GPS-promenad: rutt (JSON av [[lat, lon], …]), steg och distans. Valfria →
    // äldre dokument och icke-promenadpass avkodas som nil.
    var distanceMeters: Double? = nil
    var steps: Int? = nil
    var routeData: Data? = nil
    // HKWorkout-UUID hindrar dubbelimport från Apple Hälsa efter återställning.
    var healthKitUUID: String? = nil
    var createdByUid: String
    var createdByName: String
    var updatedAt: Date
}
