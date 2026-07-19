//
//  SyncCoordinator.swift
//  UppdragHund
//
//  Ägarsidans auto-push. Mutationsställena i vyerna anropar de publika
//  metoderna (en rad per ställe); en debouncad push laddar upp smutsiga
//  delade hundar. needsUpload är persistent, så ett missat anrop eller en
//  krasch ger bara fördröjning till nästa scenePhase-svep — aldrig dataförlust.
//

import Foundation
import SwiftData

/// Ren push-planering: vad ska upp och vad ska bort, givet lokala poster,
/// tombstones och senaste lyckade synk.
enum PushPlanner {
    struct PushPlan: Equatable {
        var upserts: Set<UUID> = []
        var deletes: Set<UUID> = []
    }

    static func plan(
        entries: [(id: UUID, updatedAt: Date?)],
        tombstoned: Set<UUID>,
        lastSyncedAt: Date?
    ) -> PushPlan {
        var plan = PushPlan(deletes: tombstoned)
        for (id, updatedAt) in entries where !tombstoned.contains(id) {
            // Utan lastSyncedAt (första pushen) eller utan tidsstämpel: ta med allt.
            if lastSyncedAt == nil || updatedAt == nil || updatedAt! > lastSyncedAt! {
                plan.upserts.insert(id)
            }
        }
        return plan
    }
}

/// Vilken delningsmodul en posttyp hör till (för tombstones och push).
protocol ModuleTagged {
    static var module: SharedModule { get }
}

extension HealthEvent: ModuleTagged { static var module: SharedModule { .health } }
extension HeatCycle: ModuleTagged { static var module: SharedModule { .heat } }
extension DiaryEntry: ModuleTagged { static var module: SharedModule { .diary } }
extension MealEntry: ModuleTagged { static var module: SharedModule { .meals } }
extension TrainingSession: ModuleTagged { static var module: SharedModule { .training } }

@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var debouncedPush: Task<Void, Never>?
    @ObservationIgnored private var cachedOwnerAuthor: ShareMapping.Author?

    private static let debounceNanoseconds: UInt64 = 3_000_000_000

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Anrop från mutationsställen

    /// Ny eller ändrad post. Stämplar updatedAt och markerar för push —
    /// via hundens dirty-flagga (egen hund) eller postens pendingUpload (delad hund).
    func entryTouched(_ entry: some SyncableEntry, dog: Dog?) {
        entry.updatedAt = .now
        guard let dog else { return }

        if dog.isShared {
            guard dog.sharePermission == .readWrite,
                  let uid = AuthService.shared.currentUserID else { return }
            if entry.createdByUid == nil {
                entry.createdByUid = uid
                entry.createdByName = cachedOwnerAuthor?.name
            }
            guard entry.createdByUid == uid else { return } // ägarens poster är fredade
            entry.pendingUpload = true
            schedulePush()
        } else {
            markDirty(dog)
        }
    }

    /// Radering av post — skriver tombstone FÖRE delete så remoteID hinner fångas.
    /// På en delad hund tombstonas bara egna poster (UI:t hindrar resten).
    func delete<Entry: SyncableEntry & ModuleTagged>(_ entry: Entry, of dog: Dog?, in context: ModelContext) {
        if let dog, let dogRemoteID = dog.remoteID, let entryRemoteID = entry.remoteID {
            let shouldTombstone: Bool
            if dog.isShared {
                shouldTombstone = dog.sharePermission == .readWrite
                    && entry.createdByUid != nil
                    && entry.createdByUid == AuthService.shared.currentUserID
            } else {
                shouldTombstone = true
            }
            if shouldTombstone {
                context.insert(SyncTombstone(
                    dogRemoteID: dogRemoteID,
                    module: Entry.module.rawValue,
                    entryRemoteID: entryRemoteID
                ))
            }
        }
        context.delete(entry)
        if let dog {
            if dog.isShared {
                schedulePush()
            } else {
                markDirty(dog)
            }
        }
    }

    /// Hundprofilen ändrad (namn/ras/födelsedatum/kön).
    func dogProfileTouched(_ dog: Dog) {
        guard !dog.isShared else { return }
        markDirty(dog)
    }

    /// Radering av en egen hund — tombstone gör att fjärrkopian städas vid nästa push.
    func deleteDog(_ dog: Dog, in context: ModelContext) {
        if !dog.isShared, let dogRemoteID = dog.remoteID {
            context.insert(SyncTombstone(dogRemoteID: dogRemoteID, module: "dog"))
        }
        context.delete(dog)
        schedulePush()
    }

    // MARK: - Molnbackup

    /// Markerar alla egna hundar för uppladdning och pushar — säkerställer att
    /// hundar som fanns före backup-funktionen (eller inte ändrats på länge)
    /// ändå speglas till molnet. Körs vid inloggning.
    func backupAllOwnDogs(uid: String) async {
        guard let container else { return }
        let context = container.mainContext
        let ownDogs = (try? context.fetch(
            FetchDescriptor<Dog>(predicate: #Predicate { !$0.isShared })
        )) ?? []
        let mine = ownDogs.filter { $0.ownerUid == uid }
        guard !mine.isEmpty else { return }
        for dog in mine { dog.needsUpload = true }
        try? context.save()
        await pushDirtyDogs()
    }

    // MARK: - Push

    /// Svep: anropas från scenePhase-hanteringen och efter debounce.
    func pushDirtyDogs() async {
        guard let container, let uid = AuthService.shared.currentUserID else { return }
        let context = container.mainContext
        let repository = SharingRepository.shared

        do {
            // Hela hundar som raderats lokalt städas först.
            let dogTombstones = try context.fetch(
                FetchDescriptor<SyncTombstone>(predicate: #Predicate { $0.module == "dog" })
            )
            for tombstone in dogTombstones {
                try await repository.deleteDogCompletely(dogRemoteID: tombstone.dogRemoteID.uuidString, ownerUid: uid)
                context.delete(tombstone)
            }

            // Mottagarsidan: egna poster/raderingar på delade hundar pushas
            // per post — de täcks inte av ägarnas dirty-flagga nedan.
            try await pushFriendEntries(context: context, uid: uid)

            let dirtyDogs = try context.fetch(
                FetchDescriptor<Dog>(predicate: #Predicate { !$0.isShared && $0.needsUpload })
            )
            guard !dirtyDogs.isEmpty else {
                try context.save()
                return
            }

            let owner = try await ownerAuthor(uid: uid)

            for dog in dirtyDogs {
                guard let dogRemoteID = dog.remoteID else { continue }

                // Molnbackup: ägaren speglar ALLTID hela hunden (dokument +
                // ALLA moduler) till sharedDogs, oavsett om den är delad.
                // Reglerna gör backupen privat — bara ägaren läser den, och
                // ev. mottagare ser bara modulerna i sin egen delning.
                try await repository.upsertDogDoc(
                    dogRemoteID: dogRemoteID.uuidString,
                    doc: ShareMapping.dogDoc(from: dog, owner: owner)
                )
                try await push(modules: Set(SharedModule.allCases), of: dog, dogRemoteID: dogRemoteID, owner: owner, context: context)

                dog.needsUpload = false
                dog.lastSyncedAt = .now
            }
            try context.save()
        } catch {
            // Offline etc. — needsUpload/tombstones ligger kvar till nästa svep.
        }
    }

    /// Mottagarens push: på delade hundar med readWrite laddas egna poster
    /// (pendingUpload) och egna raderingar (tombstones) upp per post.
    /// Reglerna kräver createdByUid == eget uid, vilket entryTouched/delete
    /// redan garanterar.
    private func pushFriendEntries(context: ModelContext, uid: String) async throws {
        let sharedDogs = try context.fetch(
            FetchDescriptor<Dog>(predicate: #Predicate { $0.isShared })
        )
        guard sharedDogs.contains(where: { $0.sharePermission == .readWrite }) else { return }

        let repository = SharingRepository.shared
        // Säkerställ författarinfo (namn på posten hos ägaren).
        _ = try await ownerAuthor(uid: uid)
        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
            .filter { $0.module != "dog" }

        for dog in sharedDogs where dog.sharePermission == .readWrite {
            guard let dogRemoteID = dog.remoteID else { continue }

            for module in SharedModule.allCases where dog.sharedModules.contains(module) {
                let moduleTombstones = tombstones.filter {
                    $0.dogRemoteID == dogRemoteID && $0.module == module.rawValue
                }
                if !moduleTombstones.isEmpty {
                    try await repository.deleteEntries(
                        dogRemoteID: dogRemoteID.uuidString,
                        module: module,
                        ids: moduleTombstones.compactMap { $0.entryRemoteID?.uuidString }
                    )
                    moduleTombstones.forEach(context.delete)
                }

                let pending = moduleEntries(module, of: dog).filter {
                    $0.0.pendingUpload && $0.0.createdByUid == uid
                }
                guard !pending.isEmpty else { continue }

                var docs: [String: Encodable] = [:]
                for (entry, dto) in pending {
                    guard let id = entry.remoteID?.uuidString else { continue }
                    docs[id] = dto
                }
                try await repository.upsertEntries(
                    dogRemoteID: dogRemoteID.uuidString,
                    module: module,
                    docs: docs
                )
                for (entry, _) in pending {
                    entry.pendingUpload = false
                }
            }
        }
    }

    private func push(
        modules: Set<SharedModule>,
        of dog: Dog,
        dogRemoteID: UUID,
        owner: ShareMapping.Author,
        context: ModelContext
    ) async throws {
        let repository = SharingRepository.shared
        let tombstones = try context.fetch(FetchDescriptor<SyncTombstone>())
            .filter { $0.dogRemoteID == dogRemoteID && $0.module != "dog" }

        for module in modules {
            let moduleTombstones = tombstones.filter { $0.module == module.rawValue }
            let tombstonedIDs = Set(moduleTombstones.compactMap(\.entryRemoteID))

            let entries: [(UUID, Date?, Encodable)] = moduleEntries(module, of: dog).compactMap { entry, dto in
                entry.remoteID.map { ($0, entry.updatedAt, dto) }
            }
            let plan = PushPlanner.plan(
                entries: entries.map { (id: $0.0, updatedAt: $0.1) },
                tombstoned: tombstonedIDs,
                lastSyncedAt: dog.lastSyncedAt
            )

            let docs = Dictionary(
                entries.filter { plan.upserts.contains($0.0) }
                    .map { ($0.0.uuidString, $0.2) },
                uniquingKeysWith: { first, _ in first }
            )
            try await repository.upsertEntries(dogRemoteID: dogRemoteID.uuidString, module: module, docs: docs)
            try await repository.deleteEntries(
                dogRemoteID: dogRemoteID.uuidString,
                module: module,
                ids: plan.deletes.map(\.uuidString)
            )
            moduleTombstones.forEach(context.delete)
        }
    }

    private func moduleEntries(_ module: SharedModule, of dog: Dog) -> [(any SyncableEntry, Encodable)] {
        guard let owner = cachedOwnerAuthor else { return [] }
        switch module {
        case .health:
            return dog.healthEvents.map { ($0, ShareMapping.dto(from: $0, fallbackAuthor: owner)) }
        case .heat:
            return dog.heatCycles.map { ($0, ShareMapping.dto(from: $0, fallbackAuthor: owner)) }
        case .diary:
            return dog.diaryEntries.map { ($0, ShareMapping.dto(from: $0, fallbackAuthor: owner)) }
        case .meals:
            return dog.mealEntries.map { ($0, ShareMapping.dto(from: $0, fallbackAuthor: owner)) }
        case .training:
            return dog.trainingSessions.map { ($0, ShareMapping.dto(from: $0, fallbackAuthor: owner)) }
        }
    }

    private func ownerAuthor(uid: String) async throws -> ShareMapping.Author {
        if let cachedOwnerAuthor, cachedOwnerAuthor.uid == uid {
            return cachedOwnerAuthor
        }
        let profile = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
        let author = ShareMapping.Author(uid: uid, name: profile?.displayName ?? String(localized: "Ägare"))
        cachedOwnerAuthor = author
        return author
    }

    private func markDirty(_ dog: Dog) {
        dog.needsUpload = true
        schedulePush()
    }

    private func schedulePush() {
        debouncedPush?.cancel()
        debouncedPush = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.pushDirtyDogs()
        }
    }
}
