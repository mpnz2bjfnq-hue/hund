//
//  Dog.swift
//  UppdragHund
//

import Foundation
import SwiftData

enum DogSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: String(localized: "Tik")
        case .male: String(localized: "Hane")
        }
    }
}

@Model
final class Dog {
    // Optional with launch-time backfill: a non-optional default would give every
    // pre-existing row the same UUID during lightweight migration.
    var remoteID: UUID?
    var name: String
    var breed: String
    var birthDate: Date
    var sex: DogSex
    var createdAt: Date

    // Lokal profilbild (liten JPEG-thumbnail). Synkas INTE till delning — foton
    // hålls medvetet lokala. nil = visa platshållare.
    var photoData: Data? = nil

    // Registrering & identitet (valfritt, lokalt — synkas inte ännu).
    var color: String? = nil
    var registrationNumber: String? = nil
    var chipNumber: String? = nil
    var breeder: String? = nil

    // Försäkring (valfritt) — visas som kort på hundprofilen så uppgifterna
    // finns till hands hos veterinären (direktreglering).
    var insuranceCompany: String? = nil
    var insuranceNumber: String? = nil
    var insurancePhone: String? = nil
    var insuranceRenewalDate: Date? = nil

    // Meriter & hälsostatus — visas som badges på hundprofilen.
    var hdResult: String? = nil        // Höftledsröntgen: A–E
    var edResult: String? = nil        // Armbågsröntgen: 0–3
    var mentalTestDone: Bool = false   // MH/BPH genomförd
    var showMerit: Bool = false        // Utställningsmerit
    var vaccinated: Bool = false

    /// Hundens normala kroppstemperatur (°C), om ägaren angett den. Används för
    /// att flagga förhöjd temp i hälsologgen.
    var normalTemperatureCelsius: Double? = nil

    // Minnesläge: satt när hunden gått bort. All data behålls för att
    // kunna hedras — hunden visas som "ängel" istället för aktiv hund.
    var passedAwayDate: Date? = nil

    // Delning. isShared == true betyder att hunden ägs av någon annan och har
    // hämtats hit via en delning; fälten nedan cachas från share-dokumentet.
    var isShared: Bool = false
    var ownerUid: String?
    var ownerDisplayName: String?
    var sharedModulesRaw: String?
    var sharePermissionRaw: String?

    // Ägarsidans synkstatus för hundar som delas ut.
    var needsUpload: Bool = false
    var lastSyncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \HealthEvent.dog)
    var healthEvents: [HealthEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \HeatCycle.dog)
    var heatCycles: [HeatCycle] = []

    @Relationship(deleteRule: .cascade, inverse: \DiaryEntry.dog)
    var diaryEntries: [DiaryEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \MealEntry.dog)
    var mealEntries: [MealEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \TrainingSession.dog)
    var trainingSessions: [TrainingSession] = []

    @Relationship(deleteRule: .cascade, inverse: \TrainingSkill.dog)
    var trainingSkills: [TrainingSkill] = []

    init(name: String, breed: String, birthDate: Date, sex: DogSex) {
        self.remoteID = UUID()
        self.name = name
        self.breed = breed
        self.birthDate = birthDate
        self.sex = sex
        self.createdAt = .now
    }
}

extension Dog {
    /// Löp gäller endast tikar — hela löp-funktionen döljs för hanar.
    var tracksHeat: Bool { sex == .female }

    /// Tröskel för förhöjd temperatur: hundens egen normaltemp om satt, annars
    /// ett generellt riktvärde (39,2 °C är övre normalgräns för hund).
    var elevatedTemperatureThreshold: Double { normalTemperatureCelsius ?? 39.2 }

    /// Är en uppmätt temperatur förhöjd för den här hunden?
    func isTemperatureElevated(_ celsius: Double) -> Bool {
        celsius > elevatedTemperatureThreshold
    }

    /// Har hunden gått bort? (Ängel — visas i minnesläge.)
    var isDeceased: Bool { passedAwayDate != nil }

    /// "2015–2024"-formaterad levnadsperiod för minnesvyer.
    var memorialYears: String {
        let born = Calendar.current.component(.year, from: birthDate)
        guard let passed = passedAwayDate else { return "\(born)–" }
        return "\(born)–\(Calendar.current.component(.year, from: passed))"
    }

    var sharedModules: Set<SharedModule> {
        get { Set(rawStorage: sharedModulesRaw) }
        set { sharedModulesRaw = newValue.isEmpty ? nil : newValue.rawStorage }
    }

    var sharePermission: SharePermission? {
        get { sharePermissionRaw.flatMap(SharePermission.init(rawValue:)) }
        set { sharePermissionRaw = newValue?.rawValue }
    }

    /// Får användaren med `uid` logga nya poster på den här hunden?
    func canLog(uid: String?) -> Bool {
        guard isShared else { return true }
        return sharePermission == .readWrite && uid != nil
    }

    func includes(_ module: SharedModule) -> Bool {
        guard isShared else { return true }
        return sharedModules.contains(module)
    }
}
