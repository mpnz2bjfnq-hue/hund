//
//  ShareMappingTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
@testable import UppdragHund

struct ShareMappingTests {

    private let author = ShareMapping.Author(uid: "owner-uid", name: "Alex")
    private let friend = ShareMapping.Author(uid: "friend-uid", name: "Kim")
    private let stamp = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Round-trips

    @Test func healthEventRoundTripPreservesAllFields() {
        let event = HealthEvent(
            type: .injury, title: "Tassskada", date: stamp,
            note: "Höger fram", bodyLocation: .frontRightLeg,
            weightKg: 31.5, temperatureCelsius: 38.6
        )
        event.updatedAt = stamp

        let dto = ShareMapping.dto(from: event, fallbackAuthor: author)
        let restored = ShareMapping.makeHealthEvent(from: dto, remoteID: UUID(), dog: makeDog())

        #expect(restored.type == .injury)
        #expect(restored.title == "Tassskada")
        #expect(restored.date == stamp)
        #expect(restored.note == "Höger fram")
        #expect(restored.bodyLocation == .frontRightLeg)
        #expect(restored.weightKg == 31.5)
        #expect(restored.temperatureCelsius == 38.6)
        #expect(restored.createdByUid == "owner-uid")
        #expect(restored.createdByName == "Alex")
        #expect(restored.updatedAt == stamp)
    }

    @Test func heatCycleRoundTripPreservesAllFields() {
        let end = stamp.addingTimeInterval(18 * 86_400)
        let cycle = HeatCycle(startDate: stamp, endDate: end)
        cycle.updatedAt = stamp

        let dto = ShareMapping.dto(from: cycle, fallbackAuthor: author)
        let restored = ShareMapping.makeHeatCycle(from: dto, remoteID: UUID(), dog: makeDog())

        #expect(restored.startDate == stamp)
        #expect(restored.endDate == end)
        #expect(restored.createdByUid == "owner-uid")
    }

    @Test func diaryEntryRoundTripPreservesAllFields() {
        let entry = DiaryEntry(
            date: stamp, bleedingLevel: 2, swellingLevel: 1,
            appetiteLevel: 4, energyLevel: 5, mood: .great
        )
        entry.updatedAt = stamp

        let dto = ShareMapping.dto(from: entry, fallbackAuthor: author)
        let restored = ShareMapping.makeDiaryEntry(from: dto, remoteID: UUID(), dog: makeDog())

        #expect(restored.bleedingLevel == 2)
        #expect(restored.swellingLevel == 1)
        #expect(restored.appetiteLevel == 4)
        #expect(restored.energyLevel == 5)
        #expect(restored.mood == .great)
    }

    @Test func mealEntryRoundTripPreservesAllFields() {
        let meal = MealEntry(type: .snack, time: stamp, name: "Torkat öra", note: "Belöning")
        meal.updatedAt = stamp

        let dto = ShareMapping.dto(from: meal, fallbackAuthor: author)
        let restored = ShareMapping.makeMealEntry(from: dto, remoteID: UUID(), dog: makeDog())

        #expect(restored.type == .snack)
        #expect(restored.name == "Torkat öra")
        #expect(restored.note == "Belöning")
    }

    @Test func trainingSessionRoundTripPreservesAllFields() {
        let session = TrainingSession(date: stamp, activity: "Inkallning", durationMinutes: 25, note: "Bra fokus")
        session.updatedAt = stamp

        let dto = ShareMapping.dto(from: session, fallbackAuthor: author)
        let restored = ShareMapping.makeTrainingSession(from: dto, remoteID: UUID(), dog: makeDog())

        #expect(restored.activity == "Inkallning")
        #expect(restored.durationMinutes == 25)
        #expect(restored.note == "Bra fokus")
    }

    @Test func dogRoundTripPreservesProfileAndOwnerInfo() {
        let birth = stamp.addingTimeInterval(-3 * 365 * 86_400)
        let dog = Dog(name: "Bella", breed: "Malinois", birthDate: birth, sex: .female)

        let doc = ShareMapping.dogDoc(from: dog, owner: author)
        let target = Dog(name: "", breed: "", birthDate: .now, sex: .male)
        ShareMapping.apply(doc, to: target)

        #expect(target.name == "Bella")
        #expect(target.breed == "Malinois")
        #expect(target.birthDate == birth)
        #expect(target.sex == .female)
        #expect(target.ownerUid == "owner-uid")
        #expect(target.ownerDisplayName == "Alex")
    }

    @Test func dogRoundTripPreservesRegistrationFields() {
        let dog = Dog(name: "Sixten", breed: "Malinois", birthDate: .now, sex: .male)
        dog.color = "Tan/kolgrå"
        dog.registrationNumber = "SE12345/2026"
        dog.chipNumber = "752098100123456"
        dog.breeder = "Kennel Example"

        let doc = ShareMapping.dogDoc(from: dog, owner: author)
        let target = Dog(name: "", breed: "", birthDate: .now, sex: .female)
        ShareMapping.apply(doc, to: target)

        #expect(target.color == "Tan/kolgrå")
        #expect(target.registrationNumber == "SE12345/2026")
        #expect(target.chipNumber == "752098100123456")
        #expect(target.breeder == "Kennel Example")
    }

    @Test func dogPhotoRoundTrips() {
        let photo = Data([0xFF, 0xD8, 0xFF])
        let dog = Dog(name: "Sixten", breed: "Malinois", birthDate: .now, sex: .male)
        dog.photoData = photo

        let doc = ShareMapping.dogDoc(from: dog, owner: author)
        let target = Dog(name: "", breed: "", birthDate: .now, sex: .female)
        ShareMapping.apply(doc, to: target)
        #expect(target.photoData == photo)
    }

    // MARK: - Foton

    @Test func diaryMappingNeverTouchesPhotoData() {
        let photo = Data([0xFF, 0xD8, 0xFF])
        let source = DiaryEntry(date: stamp, photoData: photo)
        let dto = ShareMapping.dto(from: source, fallbackAuthor: author)

        // Applicering på en post som redan har ett (lokalt) foto lämnar fotot ifred.
        let target = DiaryEntry(date: .now, photoData: photo)
        ShareMapping.apply(dto, to: target)
        #expect(target.photoData == photo)

        // Nyskapade poster från DTO har inget foto.
        let created = ShareMapping.makeDiaryEntry(from: dto, remoteID: UUID(), dog: makeDog())
        #expect(created.photoData == nil)
    }

    // MARK: - Författare

    @Test func existingAuthorshipWinsOverFallback() {
        let event = HealthEvent(type: .note, title: "Vännens post", date: stamp)
        event.createdByUid = friend.uid
        event.createdByName = friend.name

        let dto = ShareMapping.dto(from: event, fallbackAuthor: author)
        #expect(dto.createdByUid == "friend-uid")
        #expect(dto.createdByName == "Kim")
    }

    // MARK: - Okända enum-värden (framtida appversioner)

    @Test func unknownEnumRawValuesFallBackGracefully() {
        var healthDTO = ShareMapping.dto(
            from: HealthEvent(type: .vetVisit, title: "x", date: stamp),
            fallbackAuthor: author
        )
        healthDTO.type = "hologramScan"
        healthDTO.bodyLocation = "tail"
        let event = ShareMapping.makeHealthEvent(from: healthDTO, remoteID: UUID(), dog: makeDog())
        #expect(event.type == .note, "Okänd typ blir anteckning, posten tappas inte")
        #expect(event.bodyLocation == nil)

        var diaryDTO = ShareMapping.dto(from: DiaryEntry(date: stamp, mood: .good), fallbackAuthor: author)
        diaryDTO.mood = "euphoric"
        #expect(ShareMapping.makeDiaryEntry(from: diaryDTO, remoteID: UUID(), dog: makeDog()).mood == .neutral)

        var mealDTO = ShareMapping.dto(from: MealEntry(type: .snack, time: stamp, name: "x"), fallbackAuthor: author)
        mealDTO.type = "buffet"
        #expect(ShareMapping.makeMealEntry(from: mealDTO, remoteID: UUID(), dog: makeDog()).type == .meal)
    }

    @Test func remoteIDIsAssignedFromParameter() {
        let id = UUID()
        let dto = ShareMapping.dto(from: HeatCycle(startDate: stamp), fallbackAuthor: author)
        let cycle = ShareMapping.makeHeatCycle(from: dto, remoteID: id, dog: makeDog())
        #expect(cycle.remoteID == id)
    }

    private func makeDog() -> Dog {
        Dog(name: "Testhund", breed: "Schäfer", birthDate: .now, sex: .female)
    }
}
