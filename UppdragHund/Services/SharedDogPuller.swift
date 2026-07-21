//
//  SharedDogPuller.swift
//  UppdragHund
//
//  Mottagarsidans synk: hämtar hundar som delats med mig från Firestore
//  och speglar dem i den lokala SwiftData-storen som isShared-hundar,
//  så att alla befintliga vyer fungerar oförändrade.
//

import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
final class SharedDogPuller {
    static let shared = SharedDogPuller()

    /// Senaste synk-utfallet, för felsökning i UI:t (t.ex. hundlistan).
    private(set) var lastSyncMessage: String?
    private(set) var lastSyncFailed = false

    private init() {}

    /// Fjärrläget för en delad hund — byggs från Firestore men är ren data,
    /// så `apply` kan enhetstestas med fabricerade snapshots.
    struct RemoteDogSnapshot {
        var share: ShareDoc
        var dogDoc: SharedDogDoc
        var health: [UUID: HealthEventDTO] = [:]
        var heat: [UUID: HeatCycleDTO] = [:]
        var diary: [UUID: DiaryEntryDTO] = [:]
        var meals: [UUID: MealEntryDTO] = [:]
        var training: [UUID: TrainingSessionDTO] = [:]
        /// Moduler vars hämtning faktiskt lyckades. En modul som INTE finns
        /// här (men delas) får aldrig mergas — en tom dict skulle annars
        /// tolkas som "allt raderat i molnet" och radera lokala poster.
        /// nil = alla delade moduler hämtade (testers default).
        var fetchedModules: Set<SharedModule>? = nil

        var modules: Set<SharedModule> {
            Set(share.modules.compactMap(SharedModule.init(rawValue:)))
        }

        func isFetched(_ module: SharedModule) -> Bool {
            fetchedModules?.contains(module) ?? true
        }
    }

    /// Hämtar allt som delas med den inloggade användaren och speglar lokalt,
    /// samt hämtar vänners bidrag till mina egna delade hundar.
    /// Fel sväljs tyst (offline etc.) — den lokala kopian blir kvar som den är.
    func pull(context: ModelContext) async {
        guard let uid = AuthService.shared.currentUserID else {
            lastSyncMessage = String(localized: "Inte inloggad.")
            lastSyncFailed = true
            return
        }
        do {
            let shares = try await SharingRepository.shared.sharesWithMe(recipientUid: uid)
            let shareCount = shares.count
            let snapshots = try await fetchSnapshots(shares: shares)
            // Lokala hundar raderas BARA när själva delningen är borta
            // (revoke/ägarradering) — ett saknat hunddokument kan vara en
            // trasig uppladdning och får inte radera mottagarens kopia.
            let keepIDs = Set(shares.compactMap { UUID(uuidString: $0.dogRemoteID) })
            try apply(snapshots: snapshots, keepDogIDs: keepIDs, context: context)
            try await pullFriendContributions(ownerUid: uid, context: context)
            let time = Date.now.formatted(date: .omitted, time: .shortened)
            if shareCount > snapshots.count {
                // Delning finns men hunddokument saknas — ägarens uppladdning misslyckades.
                lastSyncMessage = String(localized: "\(shareCount) delning(ar) hittades men bara \(snapshots.count) hund(ar) kunde hämtas (\(time)). Be ägaren öppna appen så hunden laddas upp igen.")
                lastSyncFailed = true
            } else {
                lastSyncMessage = snapshots.isEmpty
                    ? String(localized: "Inga delningar hittades (\(time)).")
                    : String(localized: "\(snapshots.count) delad(e) hund(ar) synkade \(time).")
                lastSyncFailed = false
            }
        } catch {
            lastSyncMessage = String(localized: "Synkfel: \(error.localizedDescription)")
            lastSyncFailed = true
        }
    }

    /// Ägarsidan: hämtar poster som vänner skapat på mina egna delade hundar
    /// och mergar in dem (endast vänförfattade poster rörs — mina egna är källan).
    private func pullFriendContributions(ownerUid: String, context: ModelContext) async throws {
        let repository = SharingRepository.shared
        let sharesIOwn = try await repository.sharesIOwn(ownerUid: ownerUid)
        let sharedDogIDs = Set(sharesIOwn.map(\.dogRemoteID))
        guard !sharedDogIDs.isEmpty else { return }

        let ownDogs = try context.fetch(
            FetchDescriptor<Dog>(predicate: #Predicate { !$0.isShared })
        )

        var needsReupload = false
        for dogRemoteIDString in sharedDogIDs {
            guard let dogRemoteID = UUID(uuidString: dogRemoteIDString),
                  let dog = ownDogs.first(where: { $0.remoteID == dogRemoteID }) else { continue }

            // Självläkning: delningen finns men hunddokumentet saknas på servern
            // (avbruten uppladdning / raderat dokument) — ladda upp igen DIREKT
            // så efterföljande modulläsningar fungerar. Nätverksfel ≠ saknat
            // dokument: då hoppar vi över hunden i stället för att läka i blindo.
            let healDoc: SharedDogDoc?
            do {
                healDoc = try await repository.fetchDogDoc(dogRemoteID: dogRemoteIDString)
            } catch {
                continue
            }
            if healDoc == nil {
                dog.needsUpload = true
                // Molnträdet är tomt — nollställ synkstämpeln så nästa push
                // laddar upp ALLA poster, inte bara de nyligen ändrade.
                // (Annars blir molnkopian ett tomt skal som mottagarens pull
                // sedan tolkar som "allt raderat".)
                dog.lastSyncedAt = nil
                try? context.save()
                needsReupload = true
                await SyncCoordinator.shared.pushDirtyDogs()
            }

            let sharedModules = Set(
                sharesIOwn.filter { $0.dogRemoteID == dogRemoteIDString }
                    .flatMap(\.modules)
                    .compactMap(SharedModule.init(rawValue:))
            )

            for module in sharedModules {
                guard let documents = try? await repository.fetchEntryDocuments(dogRemoteID: dogRemoteIDString, module: module) else { continue }
                mergeFriendEntries(
                    module: module,
                    documents: documents,
                    ownerUid: ownerUid,
                    dog: dog,
                    context: context
                )
            }
        }
        try context.save()
        if needsReupload {
            await SyncCoordinator.shared.pushDirtyDogs()
        }
    }

    private func mergeFriendEntries(
        module: SharedModule,
        documents: [(id: String, snapshot: DocumentSnapshot)],
        ownerUid: String,
        dog: Dog,
        context: ModelContext
    ) {
        switch module {
        case .health:
            let remote = decodeFriendDTOs(documents, ownerUid: ownerUid) { (dto: HealthEventDTO) in dto }
            mergeFriendAuthored(remote: remote, local: dog.healthEvents, ownerUid: ownerUid, context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeHealthEvent(from: $0, remoteID: $1, dog: dog)) })
        case .heat:
            let remote = decodeFriendDTOs(documents, ownerUid: ownerUid) { (dto: HeatCycleDTO) in dto }
            mergeFriendAuthored(remote: remote, local: dog.heatCycles, ownerUid: ownerUid, context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeHeatCycle(from: $0, remoteID: $1, dog: dog)) })
        case .diary:
            let remote = decodeFriendDTOs(documents, ownerUid: ownerUid) { (dto: DiaryEntryDTO) in dto }
            mergeFriendAuthored(remote: remote, local: dog.diaryEntries, ownerUid: ownerUid, context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeDiaryEntry(from: $0, remoteID: $1, dog: dog)) })
        case .meals:
            let remote = decodeFriendDTOs(documents, ownerUid: ownerUid) { (dto: MealEntryDTO) in dto }
            mergeFriendAuthored(remote: remote, local: dog.mealEntries, ownerUid: ownerUid, context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeMealEntry(from: $0, remoteID: $1, dog: dog)) })
        case .training:
            let remote = decodeFriendDTOs(documents, ownerUid: ownerUid) { (dto: TrainingSessionDTO) in dto }
            mergeFriendAuthored(remote: remote, local: dog.trainingSessions, ownerUid: ownerUid, context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeTrainingSession(from: $0, remoteID: $1, dog: dog)) })
        }
    }

    private func decodeFriendDTOs<DTO: Decodable & FriendAuthored>(
        _ documents: [(id: String, snapshot: DocumentSnapshot)],
        ownerUid: String,
        as _: (DTO) -> DTO
    ) -> [UUID: DTO] {
        var result: [UUID: DTO] = [:]
        for (id, snapshot) in documents {
            guard let uuid = UUID(uuidString: id),
                  let dto = try? snapshot.data(as: DTO.self),
                  dto.createdByUid != ownerUid else { continue }
            result[uuid] = dto
        }
        return result
    }

    /// Som `merge`, men begränsad till vänförfattade lokala poster: mina egna
    /// poster (createdByUid == nil eller == ownerUid) rörs aldrig.
    private func mergeFriendAuthored<Entry: SyncableEntry, DTO: SyncableDTO>(
        remote: [UUID: DTO],
        local: [Entry],
        ownerUid: String,
        context: ModelContext,
        update: (DTO, Entry) -> Void,
        insert: (DTO, UUID) -> Void
    ) {
        let friendLocal = local.filter { entry in
            guard let uid = entry.createdByUid else { return false }
            return uid != ownerUid
        }
        let localByID = Dictionary(
            friendLocal.compactMap { entry in entry.remoteID.map { ($0, entry) } },
            uniquingKeysWith: { first, _ in first }
        )
        let plan = SyncPlanner.mergePlan(
            remoteIDs: remote.mapValues(\.updatedAt),
            localIDs: localByID.mapValues(\.updatedAt)
        )
        for id in plan.insert { insert(remote[id]!, id) }
        for id in plan.update {
            if let entry = localByID[id] { update(remote[id]!, entry) }
        }
        for id in plan.deleteLocal {
            if let entry = localByID[id] { context.delete(entry) }
        }
    }

    private func fetchSnapshots(shares: [ShareDoc]) async throws -> [RemoteDogSnapshot] {
        let repository = SharingRepository.shared
        var snapshots: [RemoteDogSnapshot] = []

        for share in shares {
            // Saknat hunddokument (exists == false) = ägarens uppladdning är
            // trasig — hoppa över delningen. Nätverks-/regelfel däremot
            // PROPAGERAS: annars tolkas ett tillfälligt fel som "hunden är
            // raderad" och mottagarens lokala kopia (inkl. egna opushade
            // poster) cascade-raderas.
            guard let dogDoc = try await repository.fetchDogDoc(dogRemoteID: share.dogRemoteID) else { continue }
            var snapshot = RemoteDogSnapshot(share: share, dogDoc: dogDoc, fetchedModules: [])

            for module in snapshot.modules {
                let documents: [(id: String, snapshot: DocumentSnapshot)]
                do {
                    documents = try await repository.fetchEntryDocuments(
                        dogRemoteID: share.dogRemoteID,
                        module: module
                    )
                } catch let error where error.isFirestorePermissionDenied {
                    // Regeln nekar modulen (t.ex. delningen ändrades nyss) —
                    // hoppa över modulen utan att röra lokala poster.
                    continue
                }
                snapshot.fetchedModules?.insert(module)
                for (id, document) in documents {
                    guard let uuid = UUID(uuidString: id) else { continue }
                    switch module {
                    case .health:
                        if let dto = try? document.data(as: HealthEventDTO.self) { snapshot.health[uuid] = dto }
                    case .heat:
                        if let dto = try? document.data(as: HeatCycleDTO.self) { snapshot.heat[uuid] = dto }
                    case .diary:
                        if let dto = try? document.data(as: DiaryEntryDTO.self) { snapshot.diary[uuid] = dto }
                    case .meals:
                        if let dto = try? document.data(as: MealEntryDTO.self) { snapshot.meals[uuid] = dto }
                    case .training:
                        if let dto = try? document.data(as: TrainingSessionDTO.self) { snapshot.training[uuid] = dto }
                    }
                }
            }
            snapshots.append(snapshot)
        }
        return snapshots
    }

    /// Speglar fjärrläget i den lokala storen. Ren funktion över (snapshots, context):
    /// skapar/uppdaterar/raderar isShared-hundar och deras poster.
    /// `keepDogIDs` = hundar vars delning fortfarande finns (även om hund-
    /// dokumentet inte kunde hämtas) — de raderas inte lokalt. nil = härled
    /// från snapshots (testernas gamla beteende).
    func apply(snapshots: [RemoteDogSnapshot], keepDogIDs: Set<UUID>? = nil, context: ModelContext) throws {
        let sharedDogs = try context.fetch(
            FetchDescriptor<Dog>(predicate: #Predicate { $0.isShared })
        )

        // Revoke/ägarradering: lokala delade hundar utan kvarvarande share försvinner.
        let remoteDogIDs = keepDogIDs ?? Set(snapshots.compactMap { UUID(uuidString: $0.share.dogRemoteID) })
        for dog in sharedDogs where dog.remoteID == nil || !remoteDogIDs.contains(dog.remoteID!) {
            // Schemalagda notiser (löp/hälsa) för hunden blir annars
            // oavbokbara spöken när objektet raderas.
            NotificationService.cancelAllNotifications(for: dog)
            context.delete(dog)
        }

        for snapshot in snapshots {
            guard let dogRemoteID = UUID(uuidString: snapshot.share.dogRemoteID) else { continue }

            let dog: Dog
            if let existing = sharedDogs.first(where: { $0.remoteID == dogRemoteID }) {
                dog = existing
            } else {
                dog = Dog(name: "", breed: "", birthDate: .now, sex: .female)
                dog.remoteID = dogRemoteID
                dog.isShared = true
                context.insert(dog)
            }

            ShareMapping.apply(snapshot.dogDoc, to: dog)
            dog.sharedModules = snapshot.modules
            dog.sharePermission = SharePermission(rawValue: snapshot.share.permission)
            dog.ownerDisplayName = snapshot.share.ownerDisplayName

            mergeModules(snapshot: snapshot, into: dog, context: context)
        }

        try context.save()
    }

    // MARK: - Modulvis merge

    private func mergeModules(snapshot: RemoteDogSnapshot, into dog: Dog, context: ModelContext) {
        let modules = snapshot.modules

        // En modul som delas men vars hämtning misslyckades (isFetched == false)
        // får INTE mergas — tomt innehåll skulle radera de lokala posterna.
        // En modul som inte längre delas mergas mot [:] (avsiktlig rensning).
        func shouldMerge(_ module: SharedModule) -> Bool {
            !modules.contains(module) || snapshot.isFetched(module)
        }

        // Hälsologg
        if shouldMerge(.health) {
            merge(
                remote: modules.contains(.health) ? snapshot.health : [:],
                local: dog.healthEvents,
                context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeHealthEvent(from: $0, remoteID: $1, dog: dog)) }
            )
        }
        // Löpcykler
        if shouldMerge(.heat) {
            merge(
                remote: modules.contains(.heat) ? snapshot.heat : [:],
                local: dog.heatCycles,
                context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeHeatCycle(from: $0, remoteID: $1, dog: dog)) }
            )
        }
        // Dagbok
        if shouldMerge(.diary) {
            merge(
                remote: modules.contains(.diary) ? snapshot.diary : [:],
                local: dog.diaryEntries,
                context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeDiaryEntry(from: $0, remoteID: $1, dog: dog)) }
            )
        }
        // Foder
        if shouldMerge(.meals) {
            merge(
                remote: modules.contains(.meals) ? snapshot.meals : [:],
                local: dog.mealEntries,
                context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeMealEntry(from: $0, remoteID: $1, dog: dog)) }
            )
        }
        // Träning
        if shouldMerge(.training) {
            merge(
                remote: modules.contains(.training) ? snapshot.training : [:],
                local: dog.trainingSessions,
                context: context,
                update: { ShareMapping.apply($0, to: $1) },
                insert: { context.insert(ShareMapping.makeTrainingSession(from: $0, remoteID: $1, dog: dog)) }
            )
        }
    }

    private func merge<Entry: SyncableEntry, DTO>(
        remote: [UUID: DTO],
        local: [Entry],
        context: ModelContext,
        update: (DTO, Entry) -> Void,
        insert: (DTO, UUID) -> Void
    ) where DTO: SyncableDTO {
        let localByID = Dictionary(
            local.compactMap { entry in entry.remoteID.map { ($0, entry) } },
            uniquingKeysWith: { first, _ in first }
        )
        let plan = SyncPlanner.mergePlan(
            remoteIDs: remote.mapValues(\.updatedAt),
            localIDs: localByID.mapValues(\.updatedAt),
            protectedLocal: Set(localByID.filter { $0.value.pendingUpload }.keys)
        )

        for id in plan.insert {
            insert(remote[id]!, id)
        }
        for id in plan.update {
            if let entry = localByID[id] {
                update(remote[id]!, entry)
            }
        }
        for id in plan.deleteLocal {
            if let entry = localByID[id] {
                // Fjärraderade hälsohändelser: avboka bokningsnotisen också.
                if let event = entry as? HealthEvent {
                    NotificationService.cancelHealthEventNotification(for: event)
                }
                context.delete(entry)
            }
        }
    }
}

// MARK: - Protokoll som gör den modulvisa mergen generisk

protocol SyncableEntry: PersistentModel {
    var remoteID: UUID? { get }
    var updatedAt: Date? { get set }
    var pendingUpload: Bool { get set }
    var createdByUid: String? { get set }
    var createdByName: String? { get set }
}

protocol SyncableDTO {
    var updatedAt: Date { get }
}

protocol FriendAuthored: SyncableDTO {
    var createdByUid: String { get }
}

extension HealthEvent: SyncableEntry {}
extension HeatCycle: SyncableEntry {}
extension DiaryEntry: SyncableEntry {}
extension MealEntry: SyncableEntry {}
extension TrainingSession: SyncableEntry {}

extension HealthEventDTO: FriendAuthored {}
extension HeatCycleDTO: FriendAuthored {}
extension DiaryEntryDTO: FriendAuthored {}
extension MealEntryDTO: FriendAuthored {}
extension TrainingSessionDTO: FriendAuthored {}
