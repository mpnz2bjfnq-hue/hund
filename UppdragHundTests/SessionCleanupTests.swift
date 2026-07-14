//
//  SessionCleanupTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

@MainActor
struct SessionCleanupTests {

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

    @Test func signOutRemovesSharedDogsButKeepsOwnDogs() throws {
        let context = try makeInMemoryContext()

        let ownDog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        ownDog.needsUpload = true
        ownDog.lastSyncedAt = .now
        let ownEvent = HealthEvent(type: .note, title: "min", date: .now, dog: ownDog)
        ownEvent.pendingUpload = true

        let sharedDog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        sharedDog.isShared = true
        let sharedEvent = HealthEvent(type: .note, title: "delad", date: .now, dog: sharedDog)

        [ownDog, sharedDog].forEach(context.insert)
        [ownEvent, sharedEvent].forEach(context.insert)
        context.insert(SyncTombstone(dogRemoteID: ownDog.remoteID!, module: "health", entryRemoteID: UUID()))
        try context.save()

        let store = ActiveDogStore()
        store.activeDog = sharedDog

        SessionCleanupService.handleSignOut(context: context, activeDogStore: store)

        let dogs = try context.fetch(FetchDescriptor<Dog>())
        #expect(dogs.count == 1)
        #expect(dogs.first?.name == "Rex")
        #expect(!(dogs.first?.needsUpload ?? true), "Egna hundens dirty-flagga rensas")
        #expect(dogs.first?.lastSyncedAt == nil)

        let events = try context.fetch(FetchDescriptor<HealthEvent>())
        #expect(events.count == 1, "Delade hundens post cascade-raderas")
        #expect(!(events.first?.pendingUpload ?? true), "pendingUpload rensas")

        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).isEmpty)
        #expect(store.activeDog == nil, "Aktiv delad hund nollställs")
    }

    @Test func signOutWithOnlyOwnDogsIsNoOpForThem() throws {
        let context = try makeInMemoryContext()
        let ownDog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(ownDog)
        try context.save()

        let store = ActiveDogStore()
        store.activeDog = ownDog

        SessionCleanupService.handleSignOut(context: context, activeDogStore: store)

        #expect(try context.fetch(FetchDescriptor<Dog>()).count == 1)
        #expect(store.activeDog === ownDog, "Egen aktiv hund lämnas vald")
    }
}
