//
//  PushPlannerTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

struct PushPlannerTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var t1: Date { t0.addingTimeInterval(60) }

    @Test func firstPushIncludesEverything() {
        let a = UUID(), b = UUID()
        let plan = PushPlanner.plan(
            entries: [(a, t0), (b, nil)],
            tombstoned: [],
            lastSyncedAt: nil
        )
        #expect(plan == PushPlanner.PushPlan(upserts: [a, b]))
    }

    @Test func incrementalPushIncludesOnlyNewerEntries() {
        let old = UUID(), fresh = UUID(), unstamped = UUID()
        let plan = PushPlanner.plan(
            entries: [(old, t0), (fresh, t1), (unstamped, nil)],
            tombstoned: [],
            lastSyncedAt: t0
        )
        // Poster utan tidsstämpel tas med för säkerhets skull.
        #expect(plan == PushPlanner.PushPlan(upserts: [fresh, unstamped]))
    }

    @Test func tombstonedEntriesAreDeletedNotUpserted() {
        let kept = UUID(), doomed = UUID()
        let plan = PushPlanner.plan(
            entries: [(kept, t1), (doomed, t1)],
            tombstoned: [doomed],
            lastSyncedAt: t0
        )
        #expect(plan == PushPlanner.PushPlan(upserts: [kept], deletes: [doomed]),
                "Delete vinner över upsert när båda gäller samma post")
    }

    @Test func tombstoneForAlreadyGoneEntryStillDeletes() {
        let ghost = UUID()
        let plan = PushPlanner.plan(entries: [], tombstoned: [ghost], lastSyncedAt: t0)
        #expect(plan == PushPlanner.PushPlan(deletes: [ghost]))
    }
}

@MainActor
struct SyncCoordinatorTombstoneTests {

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            Dog.self, HealthEvent.self, HeatCycle.self,
            DiaryEntry.self, MealEntry.self, TrainingSession.self,
            SyncTombstone.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func deletingOwnDogEntryWritesTombstoneAndMarksDirty() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        let event = HealthEvent(type: .weighing, title: "Vägning", date: .now, dog: dog)
        context.insert(dog)
        context.insert(event)
        try context.save()
        let entryID = event.remoteID

        SyncCoordinator.shared.delete(event, of: dog, in: context)
        try context.save()

        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
        #expect(tombstones.count == 1)
        #expect(tombstones.first?.dogRemoteID == dog.remoteID)
        #expect(tombstones.first?.module == "health")
        #expect(tombstones.first?.entryRemoteID == entryID)
        #expect(dog.needsUpload)
        #expect(try context.fetch(FetchDescriptor<HealthEvent>()).isEmpty)
    }

    @Test func deletingEntryOnSharedDogWritesNoTombstone() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        dog.isShared = true
        let event = HealthEvent(type: .note, title: "x", date: .now, dog: dog)
        context.insert(dog)
        context.insert(event)
        try context.save()

        SyncCoordinator.shared.delete(event, of: dog, in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).isEmpty,
                "Mottagarsidans raderingar hanteras i steg 9, inte via ägar-tombstones")
        #expect(!dog.needsUpload)
    }

    @Test func entryTouchedStampsUpdatedAtAndMarksOwnDogDirty() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        let meal = MealEntry(type: .meal, time: .now, name: "Frukost", dog: dog)
        context.insert(dog)
        context.insert(meal)

        SyncCoordinator.shared.entryTouched(meal, dog: dog)

        #expect(meal.updatedAt != nil)
        #expect(dog.needsUpload)
    }

    @Test func entryTouchedOnSharedDogDoesNotMarkDirty() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        dog.isShared = true
        let meal = MealEntry(type: .meal, time: .now, name: "Frukost", dog: dog)
        context.insert(dog)
        context.insert(meal)

        SyncCoordinator.shared.entryTouched(meal, dog: dog)

        #expect(meal.updatedAt != nil, "Tidsstämpeln sätts alltid")
        #expect(!dog.needsUpload, "needsUpload är ägarsidans flagga")
    }

    @Test func deletingOwnDogWritesDogTombstone() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)
        try context.save()
        let dogID = dog.remoteID

        SyncCoordinator.shared.deleteDog(dog, in: context)
        try context.save()

        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
        #expect(tombstones.count == 1)
        #expect(tombstones.first?.module == "dog")
        #expect(tombstones.first?.dogRemoteID == dogID)
        #expect(tombstones.first?.entryRemoteID == nil)
    }
}
