//
//  DogAccessTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
@testable import UppdragHund

struct DogAccessTests {

    private func makeOwnDog() -> Dog {
        Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
    }

    private func makeSharedDog(permission: SharePermission?, modules: Set<SharedModule>) -> Dog {
        let dog = makeOwnDog()
        dog.isShared = true
        dog.sharePermission = permission
        dog.sharedModules = modules
        return dog
    }

    // MARK: Egen hund

    @Test func ownDogAllowsEverythingEvenSignedOut() {
        let access = DogAccess(dog: makeOwnDog(), currentUid: nil)
        for module in SharedModule.allCases {
            #expect(access.isModuleVisible(module))
            #expect(access.canLog(in: module))
        }
        #expect(access.canModify(entryCreatedByUid: nil))
        #expect(access.canModify(entryCreatedByUid: "someone-else"))
    }

    // MARK: Delad, read

    @Test func sharedReadOnlyAllowsViewingSharedModulesOnly() {
        let dog = makeSharedDog(permission: .read, modules: [.heat, .health])
        let access = DogAccess(dog: dog, currentUid: "me")

        #expect(access.isModuleVisible(.heat))
        #expect(access.isModuleVisible(.health))
        #expect(!access.isModuleVisible(.diary))
        #expect(!access.canLog(in: .heat), "read = aldrig logga")
        #expect(!access.canModify(entryCreatedByUid: "me"), "read = aldrig ändra, ens egna")
    }

    // MARK: Delad, readWrite

    @Test func sharedReadWriteAllowsLoggingInSharedModules() {
        let dog = makeSharedDog(permission: .readWrite, modules: [.heat])
        let access = DogAccess(dog: dog, currentUid: "me")

        #expect(access.canLog(in: .heat))
        #expect(!access.canLog(in: .diary), "Ej delad modul går inte att logga i")
    }

    @Test func sharedReadWriteAllowsModifyingOwnEntriesOnly() {
        let dog = makeSharedDog(permission: .readWrite, modules: [.health])
        let access = DogAccess(dog: dog, currentUid: "me")

        #expect(access.canModify(entryCreatedByUid: "me"))
        #expect(!access.canModify(entryCreatedByUid: "owner-uid"), "Ägarens poster är fredade")
        #expect(!access.canModify(entryCreatedByUid: nil), "Poster utan författare = ägarens")
    }

    @Test func signedOutUserCannotLogOrModifyOnSharedDog() {
        let dog = makeSharedDog(permission: .readWrite, modules: [.health])
        let access = DogAccess(dog: dog, currentUid: nil)

        #expect(!access.canLog(in: .health))
        #expect(!access.canModify(entryCreatedByUid: nil))
    }

    @Test func sharedDogWithoutPermissionBehavesAsReadOnly() {
        let dog = makeSharedDog(permission: nil, modules: [.health])
        let access = DogAccess(dog: dog, currentUid: "me")

        #expect(access.isModuleVisible(.health))
        #expect(!access.canLog(in: .health))
        #expect(!access.canModify(entryCreatedByUid: "me"))
    }
}
