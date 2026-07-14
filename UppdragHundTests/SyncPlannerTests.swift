//
//  SyncPlannerTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

struct SyncPlannerTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var t1: Date { t0.addingTimeInterval(60) }

    @Test func remoteOnlyEntryIsInserted() {
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [id: t0], localIDs: [:])
        #expect(plan == MergePlan(insert: [id]))
    }

    @Test func newerRemoteEntryIsUpdated() {
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [id: t1], localIDs: [id: t0])
        #expect(plan == MergePlan(update: [id]))
    }

    @Test func olderOrEqualRemoteEntryIsNoOp() {
        let id = UUID()
        #expect(SyncPlanner.mergePlan(remoteIDs: [id: t0], localIDs: [id: t0]) == MergePlan())
        #expect(SyncPlanner.mergePlan(remoteIDs: [id: t0], localIDs: [id: t1]) == MergePlan())
    }

    @Test func localEntryWithoutTimestampIsUpdatedFromRemote() {
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [id: t0], localIDs: [id: nil])
        #expect(plan == MergePlan(update: [id]))
    }

    @Test func remoteMissingEntryIsDeletedLocally() {
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [:], localIDs: [id: t0])
        #expect(plan == MergePlan(deleteLocal: [id]))
    }

    @Test func protectedLocalEntriesSurviveRemoteAbsence() {
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [:], localIDs: [id: t0], protectedLocal: [id])
        #expect(plan == MergePlan())
    }

    @Test func mixedScenarioProducesCorrectPlan() {
        let newRemote = UUID()
        let newerRemote = UUID()
        let unchanged = UUID()
        let deleted = UUID()
        let protected_ = UUID()

        let plan = SyncPlanner.mergePlan(
            remoteIDs: [newRemote: t0, newerRemote: t1, unchanged: t0],
            localIDs: [newerRemote: t0, unchanged: t0, deleted: t0, protected_: t0],
            protectedLocal: [protected_]
        )
        #expect(plan == MergePlan(insert: [newRemote], update: [newerRemote], deleteLocal: [deleted]))
    }
}

@MainActor
struct SharedDogPullerApplyTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

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

    private func makeSnapshot(
        dogRemoteID: UUID,
        modules: [SharedModule] = [.health, .heat],
        permission: SharePermission = .read,
        health: [UUID: HealthEventDTO] = [:],
        heat: [UUID: HeatCycleDTO] = [:]
    ) -> SharedDogPuller.RemoteDogSnapshot {
        SharedDogPuller.RemoteDogSnapshot(
            share: ShareDoc(
                dogRemoteID: dogRemoteID.uuidString,
                ownerUid: "owner-uid",
                ownerDisplayName: "Anna",
                dogName: "Bella",
                recipientUid: "me",
                modules: modules.map(\.rawValue),
                permission: permission.rawValue,
                createdAt: t0,
                updatedAt: t0
            ),
            dogDoc: SharedDogDoc(
                ownerUid: "owner-uid",
                ownerDisplayName: "Anna",
                name: "Bella",
                breed: "Schäfer",
                birthDate: t0,
                sex: "female",
                updatedAt: t0
            ),
            health: health,
            heat: heat
        )
    }

    private func healthDTO(title: String) -> HealthEventDTO {
        HealthEventDTO(
            type: "weighing", title: title, date: t0,
            note: nil, bodyLocation: nil, weightKg: 30, temperatureCelsius: nil,
            createdByUid: "owner-uid", createdByName: "Anna", updatedAt: t0
        )
    }

    @Test func applyCreatesSharedDogWithEntriesAndMetadata() throws {
        let context = try makeInMemoryContext()
        let dogID = UUID()
        let entryID = UUID()
        let snapshot = makeSnapshot(dogRemoteID: dogID, health: [entryID: healthDTO(title: "Vägning")])

        try SharedDogPuller.shared.apply(snapshots: [snapshot], context: context)

        let dogs = try context.fetch(FetchDescriptor<Dog>(predicate: #Predicate { $0.isShared }))
        #expect(dogs.count == 1)
        let dog = try #require(dogs.first)
        #expect(dog.name == "Bella")
        #expect(dog.remoteID == dogID)
        #expect(dog.ownerDisplayName == "Anna")
        #expect(dog.sharePermission == .read)
        #expect(dog.sharedModules == [.health, .heat])
        #expect(dog.healthEvents.count == 1)
        #expect(dog.healthEvents.first?.remoteID == entryID)
        #expect(dog.healthEvents.first?.weightKg == 30)
    }

    @Test func applyIsIdempotent() throws {
        let context = try makeInMemoryContext()
        let snapshot = makeSnapshot(dogRemoteID: UUID(), health: [UUID(): healthDTO(title: "x")])

        try SharedDogPuller.shared.apply(snapshots: [snapshot], context: context)
        try SharedDogPuller.shared.apply(snapshots: [snapshot], context: context)

        let dogs = try context.fetch(FetchDescriptor<Dog>(predicate: #Predicate { $0.isShared }))
        #expect(dogs.count == 1)
        #expect(dogs.first?.healthEvents.count == 1)
    }

    @Test func applyRemovesRevokedDogAndItsEntries() throws {
        let context = try makeInMemoryContext()
        let snapshot = makeSnapshot(dogRemoteID: UUID(), health: [UUID(): healthDTO(title: "x")])
        try SharedDogPuller.shared.apply(snapshots: [snapshot], context: context)

        // Nästa pull utan snapshotet = delningen återkallad
        try SharedDogPuller.shared.apply(snapshots: [], context: context)

        #expect(try context.fetch(FetchDescriptor<Dog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HealthEvent>()).isEmpty, "Cascade städar posterna")
    }

    @Test func applyNeverTouchesOwnDogs() throws {
        let context = try makeInMemoryContext()
        let ownDog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(ownDog)
        try context.save()

        try SharedDogPuller.shared.apply(snapshots: [], context: context)

        let dogs = try context.fetch(FetchDescriptor<Dog>())
        #expect(dogs.count == 1)
        #expect(dogs.first?.name == "Rex")
    }

    @Test func applyRemovesEntriesOfDelistedModules() throws {
        let context = try makeInMemoryContext()
        let dogID = UUID()
        let full = makeSnapshot(dogRemoteID: dogID, modules: [.health], health: [UUID(): healthDTO(title: "x")])
        try SharedDogPuller.shared.apply(snapshots: [full], context: context)
        #expect(try context.fetch(FetchDescriptor<HealthEvent>()).count == 1)

        // Ägaren har tagit bort hälsomodulen ur delningen
        let narrowed = makeSnapshot(dogRemoteID: dogID, modules: [.heat])
        try SharedDogPuller.shared.apply(snapshots: [narrowed], context: context)

        #expect(try context.fetch(FetchDescriptor<HealthEvent>()).isEmpty)
        let dog = try #require(try context.fetch(FetchDescriptor<Dog>()).first)
        #expect(dog.sharedModules == [.heat])
    }

    @Test func applyRespectsLastWriteWinsAndProtectsPendingUploads() throws {
        let context = try makeInMemoryContext()
        let dogID = UUID()
        let entryID = UUID()
        let snapshot = makeSnapshot(dogRemoteID: dogID, modules: [.health], health: [entryID: healthDTO(title: "Original")])
        try SharedDogPuller.shared.apply(snapshots: [snapshot], context: context)

        // Lokal post är nyare än fjärrposten -> ska inte skrivas över
        let dog = try #require(try context.fetch(FetchDescriptor<Dog>()).first)
        let entry = try #require(dog.healthEvents.first)
        entry.title = "Lokalt ändrad"
        entry.updatedAt = t0.addingTimeInterval(120)

        // Vännens egen opushade post får inte raderas trots att den saknas remote
        let pending = HealthEvent(type: .note, title: "Min opushade", date: .now, dog: dog)
        pending.pendingUpload = true
        context.insert(pending)
        try context.save()

        try SharedDogPuller.shared.apply(snapshots: [snapshot], context: context)

        #expect(entry.title == "Lokalt ändrad", "Nyare lokal version vinner")
        let titles = Set(dog.healthEvents.map(\.title))
        #expect(titles.contains("Min opushade"), "pendingUpload-poster skyddas")
    }
}
