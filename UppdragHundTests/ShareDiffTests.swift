//
//  ShareDiffTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
@testable import UppdragHund

struct ShareDiffTests {

    @Test func addedModulesAreNewMinusOld() {
        let added = ShareDiff.modulesToAdd(old: [.health], new: [.health, .heat, .diary])
        #expect(added == [.heat, .diary])
    }

    @Test func removedModulesAreOldMinusNew() {
        let removed = ShareDiff.modulesToRemove(old: [.health, .meals, .training], new: [.health])
        #expect(removed == [.meals, .training])
    }

    @Test func identicalSetsProduceEmptyDiffs() {
        let modules: Set<SharedModule> = [.heat, .diary]
        #expect(ShareDiff.modulesToAdd(old: modules, new: modules).isEmpty)
        #expect(ShareDiff.modulesToRemove(old: modules, new: modules).isEmpty)
    }

    @Test func shareDocumentIDIsDogIDUnderscoreRecipient() {
        let id = ShareDoc.documentID(dogRemoteID: "ABC-123", recipientUid: "uid-42")
        #expect(id == "ABC-123_uid-42")

        let doc = ShareDoc(
            dogRemoteID: "ABC-123",
            ownerUid: "owner",
            ownerDisplayName: "Alex",
            dogName: "Bella",
            recipientUid: "uid-42",
            modules: ["health"],
            permission: "read",
            createdAt: .now,
            updatedAt: .now
        )
        #expect(doc.documentID == "ABC-123_uid-42")
    }
}
