//
//  DogShareService.swift
//  UppdragHund
//
//  Ägarsidans delningsflöde: skapa/ändra/återkalla delningar och
//  ladda upp hunddata till Firestore.
//

import Foundation
import SwiftData

/// Ren difflogik för moduländringar — testbar utan Firestore.
enum ShareDiff {
    static func modulesToAdd(old: Set<SharedModule>, new: Set<SharedModule>) -> Set<SharedModule> {
        new.subtracting(old)
    }

    static func modulesToRemove(old: Set<SharedModule>, new: Set<SharedModule>) -> Set<SharedModule> {
        old.subtracting(new)
    }
}

@MainActor
final class DogShareService {
    static let shared = DogShareService()

    private let repository = SharingRepository.shared

    private init() {}

    /// Skapar en ny delning: hunddokument + share-dokument + full push av valda moduler.
    func share(
        dog: Dog,
        withFriendUid recipientUid: String,
        modules: Set<SharedModule>,
        permission: SharePermission,
        owner: ShareMapping.Author
    ) async throws {
        guard let dogRemoteID = dog.remoteID?.uuidString else {
            throw ShareError.missingRemoteID
        }

        try await repository.upsertDogDoc(
            dogRemoteID: dogRemoteID,
            doc: ShareMapping.dogDoc(from: dog, owner: owner)
        )

        let now = Date.now
        let shareDoc = ShareDoc(
            dogRemoteID: dogRemoteID,
            ownerUid: owner.uid,
            ownerDisplayName: owner.name,
            dogName: dog.name,
            recipientUid: recipientUid,
            modules: modules.map(\.rawValue).sorted(),
            permission: permission.rawValue,
            createdAt: now,
            updatedAt: now
        )
        try await repository.upsertShare(shareDoc)

        try await push(modules: modules, of: dog, owner: owner)
        dog.lastSyncedAt = .now
    }

    /// Uppdaterar en befintlig delning. Borttagna modulers data raderas från
    /// servern (integritet: det som slutar delas ska inte ligga kvar), om inte
    /// någon annan delning av samma hund fortfarande omfattar modulen.
    func updateShare(
        _ existing: ShareDoc,
        dog: Dog,
        newModules: Set<SharedModule>,
        newPermission: SharePermission,
        owner: ShareMapping.Author
    ) async throws {
        let oldModules = Set(existing.modules.compactMap(SharedModule.init(rawValue:)))

        var updated = existing
        updated.modules = newModules.map(\.rawValue).sorted()
        updated.permission = newPermission.rawValue
        updated.updatedAt = .now
        try await repository.upsertShare(updated)

        let added = ShareDiff.modulesToAdd(old: oldModules, new: newModules)
        if !added.isEmpty {
            try await push(modules: added, of: dog, owner: owner)
        }

        let removed = ShareDiff.modulesToRemove(old: oldModules, new: newModules)
        for module in removed where !(try await moduleStillShared(module, dogRemoteID: existing.dogRemoteID)) {
            try await repository.deleteAllEntries(dogRemoteID: existing.dogRemoteID, module: module)
        }
    }

    /// Mottagaren tar bort en delning från sin sida: share-dokumentet raderas
    /// (reglerna tillåter mottagaren) och den lokala kopian tas bort direkt.
    /// Ägarens data under sharedDogs/ rörs inte — den städar ägaren själv.
    func stopReceiving(dog: Dog, context: ModelContext) async throws {
        guard dog.isShared,
              let remoteID = dog.remoteID?.uuidString,
              let uid = AuthService.shared.currentUserID else { return }
        try await repository.deleteShare(dogRemoteID: remoteID, recipientUid: uid)
        context.delete(dog)
        try context.save()
    }

    /// Återkallar en delning. Var det hundens sista delning städas allt på servern.
    func revoke(_ share: ShareDoc) async throws {
        try await repository.deleteShare(dogRemoteID: share.dogRemoteID, recipientUid: share.recipientUid)
        let remaining = try await repository.shares(forDog: share.dogRemoteID)
        if remaining.isEmpty {
            try await repository.deleteDogCompletely(dogRemoteID: share.dogRemoteID)
        }
    }

    /// Full push av angivna modulers samtliga poster.
    func push(modules: Set<SharedModule>, of dog: Dog, owner: ShareMapping.Author) async throws {
        guard let dogRemoteID = dog.remoteID?.uuidString else {
            throw ShareError.missingRemoteID
        }

        for module in modules {
            var docs: [String: Encodable] = [:]
            switch module {
            case .health:
                for event in dog.healthEvents {
                    guard let id = event.remoteID?.uuidString else { continue }
                    stampIfNeeded(&event.updatedAt)
                    docs[id] = ShareMapping.dto(from: event, fallbackAuthor: owner)
                }
            case .heat:
                for cycle in dog.heatCycles {
                    guard let id = cycle.remoteID?.uuidString else { continue }
                    stampIfNeeded(&cycle.updatedAt)
                    docs[id] = ShareMapping.dto(from: cycle, fallbackAuthor: owner)
                }
            case .diary:
                for entry in dog.diaryEntries {
                    guard let id = entry.remoteID?.uuidString else { continue }
                    stampIfNeeded(&entry.updatedAt)
                    docs[id] = ShareMapping.dto(from: entry, fallbackAuthor: owner)
                }
            case .meals:
                for meal in dog.mealEntries {
                    guard let id = meal.remoteID?.uuidString else { continue }
                    stampIfNeeded(&meal.updatedAt)
                    docs[id] = ShareMapping.dto(from: meal, fallbackAuthor: owner)
                }
            case .training:
                for session in dog.trainingSessions {
                    guard let id = session.remoteID?.uuidString else { continue }
                    stampIfNeeded(&session.updatedAt)
                    docs[id] = ShareMapping.dto(from: session, fallbackAuthor: owner)
                }
            }
            try await repository.upsertEntries(dogRemoteID: dogRemoteID, module: module, docs: docs)
        }
    }

    private func moduleStillShared(_ module: SharedModule, dogRemoteID: String) async throws -> Bool {
        try await repository.shares(forDog: dogRemoteID)
            .contains { $0.modules.contains(module.rawValue) }
    }

    private func stampIfNeeded(_ updatedAt: inout Date?) {
        if updatedAt == nil {
            updatedAt = .now
        }
    }

    enum ShareError: LocalizedError {
        case missingRemoteID

        var errorDescription: String? {
            switch self {
            case .missingRemoteID: "Hunden saknar synk-ID. Starta om appen och försök igen."
            }
        }
    }
}
