//
//  SharingTypesTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

struct SharingTypesTests {

    @MainActor
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

    private func makeDog() -> Dog {
        Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
    }

    // MARK: sharedModules round-trip

    @Test func sharedModulesRoundTripsThroughRawStorage() {
        let dog = makeDog()
        dog.sharedModules = [.health, .heat, .diary]
        #expect(Set(rawStorage: dog.sharedModulesRaw) == [.health, .heat, .diary])
    }

    @Test func sharedModulesHandlesNilEmptyAndUnknownRawValues() {
        #expect(Set<SharedModule>(rawStorage: nil).isEmpty)
        #expect(Set<SharedModule>(rawStorage: "").isEmpty)
        // Okända värden (t.ex. modul från en framtida appversion) ignoreras tyst.
        #expect(Set<SharedModule>(rawStorage: "health,framtida,heat") == [.health, .heat])
    }

    @Test func settingEmptyModulesClearsRawStorage() {
        let dog = makeDog()
        dog.sharedModules = [.meals]
        dog.sharedModules = []
        #expect(dog.sharedModulesRaw == nil)
    }

    @Test func rawStorageIsDeterministicallySorted() {
        #expect(Set<SharedModule>([.training, .health]).rawStorage == "health,training")
    }

    // MARK: canLog / includes

    @Test func ownDogAllowsEverything() {
        let dog = makeDog()
        #expect(dog.canLog(uid: "anyone"))
        #expect(dog.canLog(uid: nil))
        for module in SharedModule.allCases {
            #expect(dog.includes(module))
        }
    }

    @Test func sharedReadOnlyDogForbidsLogging() {
        let dog = makeDog()
        dog.isShared = true
        dog.sharePermission = .read
        #expect(!dog.canLog(uid: "friend-uid"))
    }

    @Test func sharedReadWriteDogAllowsLoggingForSignedInUser() {
        let dog = makeDog()
        dog.isShared = true
        dog.sharePermission = .readWrite
        #expect(dog.canLog(uid: "friend-uid"))
        #expect(!dog.canLog(uid: nil), "Utloggad användare kan inte logga")
    }

    @Test func sharedDogWithoutPermissionFieldForbidsLogging() {
        let dog = makeDog()
        dog.isShared = true
        #expect(!dog.canLog(uid: "friend-uid"))
    }

    @Test func sharedDogOnlyIncludesListedModules() {
        let dog = makeDog()
        dog.isShared = true
        dog.sharedModules = [.heat]
        #expect(dog.includes(.heat))
        #expect(!dog.includes(.diary))
    }

    // MARK: schema

    @MainActor
    @Test func extendedSchemaAcceptsAllModelsIncludingTombstone() throws {
        let context = try makeInMemoryContext()
        let dog = makeDog()
        context.insert(dog)
        context.insert(SyncTombstone(dogRemoteID: dog.remoteID!, module: SharedModule.health.rawValue, entryRemoteID: UUID()))
        try context.save()

        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
        #expect(tombstones.count == 1)
        #expect(tombstones.first?.module == "health")
    }
}
