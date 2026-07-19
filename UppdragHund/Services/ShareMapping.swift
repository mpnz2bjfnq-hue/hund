//
//  ShareMapping.swift
//  UppdragHund
//
//  Ren mappning mellan SwiftData-modeller och Firestore-DTO:er.
//  Inga Firestore- eller nätverksberoenden — fullt enhetstestbar.
//

import Foundation

enum ShareMapping {

    /// Författarinfo för poster som saknar egen (dvs. skapade av ägaren lokalt).
    struct Author {
        var uid: String
        var name: String
    }

    // MARK: - Dog

    static func dogDoc(from dog: Dog, owner: Author) -> SharedDogDoc {
        SharedDogDoc(
            ownerUid: owner.uid,
            ownerDisplayName: owner.name,
            name: dog.name,
            breed: dog.breed,
            birthDate: dog.birthDate,
            sex: dog.sex.rawValue,
            updatedAt: .now,
            color: dog.color,
            registrationNumber: dog.registrationNumber,
            chipNumber: dog.chipNumber,
            breeder: dog.breeder,
            hdResult: dog.hdResult,
            edResult: dog.edResult,
            mentalTestDone: dog.mentalTestDone,
            showMerit: dog.showMerit,
            vaccinated: dog.vaccinated,
            photoData: dog.photoData
        )
    }

    static func apply(_ doc: SharedDogDoc, to dog: Dog) {
        dog.name = doc.name
        dog.breed = doc.breed
        dog.birthDate = doc.birthDate
        dog.sex = DogSex(rawValue: doc.sex) ?? dog.sex
        dog.ownerUid = doc.ownerUid
        dog.ownerDisplayName = doc.ownerDisplayName
        dog.color = doc.color
        dog.registrationNumber = doc.registrationNumber
        dog.chipNumber = doc.chipNumber
        dog.breeder = doc.breeder
        dog.hdResult = doc.hdResult
        dog.edResult = doc.edResult
        dog.mentalTestDone = doc.mentalTestDone ?? false
        dog.showMerit = doc.showMerit ?? false
        dog.vaccinated = doc.vaccinated ?? false
        dog.photoData = doc.photoData
    }

    // MARK: - HealthEvent

    static func dto(from event: HealthEvent, fallbackAuthor: Author) -> HealthEventDTO {
        HealthEventDTO(
            type: event.type.rawValue,
            title: event.title,
            date: event.date,
            note: event.note,
            bodyLocation: event.bodyLocation?.rawValue,
            weightKg: event.weightKg,
            temperatureCelsius: event.temperatureCelsius,
            injuryViewRaw: event.injuryViewRaw,
            injuryX: event.injuryX,
            injuryY: event.injuryY,
            injuryStatusRaw: event.injuryStatusRaw,
            createdByUid: event.createdByUid ?? fallbackAuthor.uid,
            createdByName: event.createdByName ?? fallbackAuthor.name,
            updatedAt: event.updatedAt ?? .now
        )
    }

    static func apply(_ dto: HealthEventDTO, to event: HealthEvent) {
        // Okänd typ (från nyare appversion) blir en anteckning hellre än att posten tappas.
        event.type = HealthEventType(rawValue: dto.type) ?? .note
        event.title = dto.title
        event.date = dto.date
        event.note = dto.note
        event.bodyLocation = dto.bodyLocation.flatMap(BodyLocation.init(rawValue:))
        event.weightKg = dto.weightKg
        event.temperatureCelsius = dto.temperatureCelsius
        event.injuryViewRaw = dto.injuryViewRaw
        event.injuryX = dto.injuryX
        event.injuryY = dto.injuryY
        event.injuryStatusRaw = dto.injuryStatusRaw
        event.createdByUid = dto.createdByUid
        event.createdByName = dto.createdByName
        event.updatedAt = dto.updatedAt
    }

    static func makeHealthEvent(from dto: HealthEventDTO, remoteID: UUID, dog: Dog) -> HealthEvent {
        let event = HealthEvent(type: .note, title: "", date: dto.date, dog: dog)
        event.remoteID = remoteID
        apply(dto, to: event)
        return event
    }

    // MARK: - HeatCycle

    static func dto(from cycle: HeatCycle, fallbackAuthor: Author) -> HeatCycleDTO {
        HeatCycleDTO(
            startDate: cycle.startDate,
            endDate: cycle.endDate,
            createdByUid: cycle.createdByUid ?? fallbackAuthor.uid,
            createdByName: cycle.createdByName ?? fallbackAuthor.name,
            updatedAt: cycle.updatedAt ?? .now
        )
    }

    static func apply(_ dto: HeatCycleDTO, to cycle: HeatCycle) {
        cycle.startDate = dto.startDate
        cycle.endDate = dto.endDate
        cycle.createdByUid = dto.createdByUid
        cycle.createdByName = dto.createdByName
        cycle.updatedAt = dto.updatedAt
    }

    static func makeHeatCycle(from dto: HeatCycleDTO, remoteID: UUID, dog: Dog) -> HeatCycle {
        let cycle = HeatCycle(startDate: dto.startDate, dog: dog)
        cycle.remoteID = remoteID
        apply(dto, to: cycle)
        return cycle
    }

    // MARK: - DiaryEntry

    static func dto(from entry: DiaryEntry, fallbackAuthor: Author) -> DiaryEntryDTO {
        DiaryEntryDTO(
            date: entry.date,
            bleedingLevel: entry.bleedingLevel,
            swellingLevel: entry.swellingLevel,
            appetiteLevel: entry.appetiteLevel,
            energyLevel: entry.energyLevel,
            mood: entry.mood.rawValue,
            photoData: entry.photoData,
            createdByUid: entry.createdByUid ?? fallbackAuthor.uid,
            createdByName: entry.createdByName ?? fallbackAuthor.name,
            updatedAt: entry.updatedAt ?? .now
        )
    }

    static func apply(_ dto: DiaryEntryDTO, to entry: DiaryEntry) {
        entry.date = dto.date
        entry.bleedingLevel = dto.bleedingLevel
        entry.swellingLevel = dto.swellingLevel
        entry.appetiteLevel = dto.appetiteLevel
        entry.energyLevel = dto.energyLevel
        entry.mood = DiaryMood(rawValue: dto.mood) ?? .neutral
        // Behåll ett befintligt lokalt foto om molnkopian saknar det (t.ex.
        // äldre backup), men skriv annars över med molnets foto.
        if let photo = dto.photoData { entry.photoData = photo }
        entry.createdByUid = dto.createdByUid
        entry.createdByName = dto.createdByName
        entry.updatedAt = dto.updatedAt
    }

    static func makeDiaryEntry(from dto: DiaryEntryDTO, remoteID: UUID, dog: Dog) -> DiaryEntry {
        let entry = DiaryEntry(date: dto.date, dog: dog)
        entry.remoteID = remoteID
        apply(dto, to: entry)
        return entry
    }

    // MARK: - MealEntry

    static func dto(from meal: MealEntry, fallbackAuthor: Author) -> MealEntryDTO {
        MealEntryDTO(
            type: meal.type.rawValue,
            time: meal.time,
            name: meal.name,
            note: meal.note,
            createdByUid: meal.createdByUid ?? fallbackAuthor.uid,
            createdByName: meal.createdByName ?? fallbackAuthor.name,
            updatedAt: meal.updatedAt ?? .now
        )
    }

    static func apply(_ dto: MealEntryDTO, to meal: MealEntry) {
        meal.type = MealType(rawValue: dto.type) ?? .meal
        meal.time = dto.time
        meal.name = dto.name
        meal.note = dto.note
        meal.createdByUid = dto.createdByUid
        meal.createdByName = dto.createdByName
        meal.updatedAt = dto.updatedAt
    }

    static func makeMealEntry(from dto: MealEntryDTO, remoteID: UUID, dog: Dog) -> MealEntry {
        let meal = MealEntry(type: .meal, time: dto.time, name: dto.name, dog: dog)
        meal.remoteID = remoteID
        apply(dto, to: meal)
        return meal
    }

    // MARK: - TrainingSession

    static func dto(from session: TrainingSession, fallbackAuthor: Author) -> TrainingSessionDTO {
        TrainingSessionDTO(
            date: session.date,
            activity: session.activity,
            durationMinutes: session.durationMinutes,
            note: session.note,
            distanceMeters: session.distanceMeters,
            steps: session.steps,
            routeData: session.routeData,
            healthKitUUID: session.healthKitUUID,
            createdByUid: session.createdByUid ?? fallbackAuthor.uid,
            createdByName: session.createdByName ?? fallbackAuthor.name,
            updatedAt: session.updatedAt ?? .now
        )
    }

    static func apply(_ dto: TrainingSessionDTO, to session: TrainingSession) {
        session.date = dto.date
        session.activity = dto.activity
        session.durationMinutes = dto.durationMinutes
        session.note = dto.note
        session.distanceMeters = dto.distanceMeters
        session.steps = dto.steps
        session.routeData = dto.routeData
        session.healthKitUUID = dto.healthKitUUID
        session.createdByUid = dto.createdByUid
        session.createdByName = dto.createdByName
        session.updatedAt = dto.updatedAt
    }

    static func makeTrainingSession(from dto: TrainingSessionDTO, remoteID: UUID, dog: Dog) -> TrainingSession {
        let session = TrainingSession(date: dto.date, activity: dto.activity, dog: dog)
        session.remoteID = remoteID
        apply(dto, to: session)
        return session
    }
}
