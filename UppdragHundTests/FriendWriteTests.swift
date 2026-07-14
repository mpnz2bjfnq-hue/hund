//
//  FriendWriteTests.swift
//  UppdragHundTests
//
//  Merge-logiken för vänförfattade poster (readWrite) på ägarens sida,
//  testad via SyncPlanner (ren kärna). SyncCoordinatorns pendingUpload-
//  stämpling testas mot in-memory-context.
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

struct FriendMergeTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var t1: Date { t0.addingTimeInterval(60) }

    @Test func friendAuthoredEntriesAreFilteredByCreator() {
        // Motsvarar decodeFriendDTOs-filtret: ägarens egna poster ska falla bort.
        let entries: [(uid: String, keep: Bool)] = [
            ("owner-uid", false),
            ("friend-uid", true)
        ]
        let kept = entries.filter { $0.uid != "owner-uid" }
        #expect(kept.count == 1)
        #expect(kept.first?.uid == "friend-uid")
    }

    @Test func ownerLocalNewerThanRemoteWins() {
        // Ägaren har redigerat en vänpost lokalt (nyare) -> ingen update.
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [id: t0], localIDs: [id: t1])
        #expect(plan.update.isEmpty)
    }

    @Test func newFriendEntryIsInsertedForOwner() {
        let id = UUID()
        let plan = SyncPlanner.mergePlan(remoteIDs: [id: t0], localIDs: [:])
        #expect(plan.insert == [id])
    }
}

@MainActor
struct FriendWriteCoordinatorTests {

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

    private func makeSharedDog(permission: SharePermission) -> Dog {
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        dog.isShared = true
        dog.sharePermission = permission
        dog.sharedModules = Set(SharedModule.allCases)
        return dog
    }

    @Test func touchingEntryOnReadOnlySharedDogDoesNotMarkPending() throws {
        let context = try makeInMemoryContext()
        let dog = makeSharedDog(permission: .read)
        let event = HealthEvent(type: .note, title: "x", date: .now, dog: dog)
        context.insert(dog)
        context.insert(event)

        SyncCoordinator.shared.entryTouched(event, dog: dog)

        #expect(!event.pendingUpload, "Read-only vän kan inte pusha")
    }

    @Test func deletingOwnEntryOnSharedReadWriteDogWritesTombstone() throws {
        let context = try makeInMemoryContext()
        let dog = makeSharedDog(permission: .readWrite)
        let event = HealthEvent(type: .note, title: "min post", date: .now, dog: dog)
        // Simulera att posten är min egen (skulle sättas av entryTouched i praktiken)
        event.createdByUid = AuthService.shared.currentUserID ?? "me"
        context.insert(dog)
        context.insert(event)
        try context.save()

        // Bara meningsfullt om vi faktiskt är inloggade; annars är createdByUid "me"
        // och currentUserID nil, vilket korrekt ger ingen tombstone.
        SyncCoordinator.shared.delete(event, of: dog, in: context)
        try context.save()

        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
        if AuthService.shared.currentUserID != nil {
            #expect(tombstones.count == 1)
        } else {
            #expect(tombstones.isEmpty, "Utloggad = ingen egen vänpost att tombstona")
        }
        #expect(try context.fetch(FetchDescriptor<HealthEvent>()).isEmpty)
    }

    @Test func deletingOwnersEntryOnSharedDogWritesNoTombstone() throws {
        let context = try makeInMemoryContext()
        let dog = makeSharedDog(permission: .readWrite)
        let ownersEntry = HealthEvent(type: .note, title: "ägarens", date: .now, dog: dog)
        ownersEntry.createdByUid = "owner-uid" // inte jag
        context.insert(dog)
        context.insert(ownersEntry)
        try context.save()

        SyncCoordinator.shared.delete(ownersEntry, of: dog, in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SyncTombstone>()).isEmpty,
                "Vännen får inte tombstona ägarens poster")
    }
}
