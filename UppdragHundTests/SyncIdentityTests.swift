//
//  SyncIdentityTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

struct SyncIdentityTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([
            Dog.self, HealthEvent.self, HeatCycle.self,
            DiaryEntry.self, MealEntry.self, TrainingSession.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    @Test func newModelsGetRemoteIDFromInit() throws {
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        #expect(dog.remoteID != nil)
        #expect(HealthEvent(type: .weighing, title: "Vägning", date: .now).remoteID != nil)
        #expect(HeatCycle(startDate: .now).remoteID != nil)
        #expect(DiaryEntry(date: .now).remoteID != nil)
        #expect(MealEntry(type: .meal, time: .now, name: "Frukost").remoteID != nil)
        #expect(TrainingSession(date: .now, activity: "Inkallning").remoteID != nil)
    }

    @MainActor
    @Test func backfillAssignsUniqueIDsToRowsWithoutOne() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        let event = HealthEvent(type: .vetVisit, title: "Besök", date: .now, dog: dog)
        let cycle = HeatCycle(startDate: .now, dog: dog)
        context.insert(dog)
        context.insert(event)
        context.insert(cycle)
        // Simulera rader migrerade från gamla schemat (utan ID)
        dog.remoteID = nil
        event.remoteID = nil
        cycle.remoteID = nil
        try context.save()

        try SyncIdentityService.backfillRemoteIDs(context: context)

        let ids = [dog.remoteID, event.remoteID, cycle.remoteID].compactMap { $0 }
        #expect(ids.count == 3)
        #expect(Set(ids).count == 3, "Alla backfillade ID:n ska vara unika")
    }

    @MainActor
    @Test func backfillIsIdempotentAndKeepsExistingIDs() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)
        try context.save()
        let originalID = dog.remoteID
        #expect(originalID != nil)

        try SyncIdentityService.backfillRemoteIDs(context: context)
        try SyncIdentityService.backfillRemoteIDs(context: context)

        #expect(dog.remoteID == originalID, "Redan satta ID:n ska inte ändras")
    }
}
