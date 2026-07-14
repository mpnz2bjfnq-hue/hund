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

        var modules: Set<SharedModule> {
            Set(share.modules.compactMap(SharedModule.init(rawValue:)))
        }
    }

    /// Hämtar allt som delas med den inloggade användaren och speglar lokalt.
    /// Fel sväljs tyst (offline etc.) — den lokala kopian blir kvar som den är.
    func pull(context: ModelContext) async {
        guard let uid = AuthService.shared.currentUserID else { return }
        do {
            let snapshots = try await fetchSnapshots(recipientUid: uid)
            try apply(snapshots: snapshots, context: context)
        } catch {
            // Offline eller regelfel — behåll den lokala kopian tyst.
        }
    }

    private func fetchSnapshots(recipientUid: String) async throws -> [RemoteDogSnapshot] {
        let repository = SharingRepository.shared
        var snapshots: [RemoteDogSnapshot] = []

        for share in try await repository.sharesWithMe(recipientUid: recipientUid) {
            // Saknat hunddokument = ägaren har raderat hunden; att den utelämnas
            // ur snapshot-listan gör att apply städar bort den lokala kopian.
            guard let dogDoc = try await repository.fetchDogDoc(dogRemoteID: share.dogRemoteID) else { continue }
            var snapshot = RemoteDogSnapshot(share: share, dogDoc: dogDoc)

            for module in snapshot.modules {
                let documents = try await repository.fetchEntryDocuments(
                    dogRemoteID: share.dogRemoteID,
                    module: module
                )
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
    func apply(snapshots: [RemoteDogSnapshot], context: ModelContext) throws {
        let sharedDogs = try context.fetch(
            FetchDescriptor<Dog>(predicate: #Predicate { $0.isShared })
        )

        // Revoke/ägarradering: lokala delade hundar utan kvarvarande share försvinner.
        let remoteDogIDs = Set(snapshots.compactMap { UUID(uuidString: $0.share.dogRemoteID) })
        for dog in sharedDogs where dog.remoteID == nil || !remoteDogIDs.contains(dog.remoteID!) {
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

        // Hälsologg
        merge(
            remote: modules.contains(.health) ? snapshot.health : [:],
            local: dog.healthEvents,
            context: context,
            update: { ShareMapping.apply($0, to: $1) },
            insert: { context.insert(ShareMapping.makeHealthEvent(from: $0, remoteID: $1, dog: dog)) }
        )
        // Löpcykler
        merge(
            remote: modules.contains(.heat) ? snapshot.heat : [:],
            local: dog.heatCycles,
            context: context,
            update: { ShareMapping.apply($0, to: $1) },
            insert: { context.insert(ShareMapping.makeHeatCycle(from: $0, remoteID: $1, dog: dog)) }
        )
        // Dagbok
        merge(
            remote: modules.contains(.diary) ? snapshot.diary : [:],
            local: dog.diaryEntries,
            context: context,
            update: { ShareMapping.apply($0, to: $1) },
            insert: { context.insert(ShareMapping.makeDiaryEntry(from: $0, remoteID: $1, dog: dog)) }
        )
        // Foder
        merge(
            remote: modules.contains(.meals) ? snapshot.meals : [:],
            local: dog.mealEntries,
            context: context,
            update: { ShareMapping.apply($0, to: $1) },
            insert: { context.insert(ShareMapping.makeMealEntry(from: $0, remoteID: $1, dog: dog)) }
        )
        // Träning
        merge(
            remote: modules.contains(.training) ? snapshot.training : [:],
            local: dog.trainingSessions,
            context: context,
            update: { ShareMapping.apply($0, to: $1) },
            insert: { context.insert(ShareMapping.makeTrainingSession(from: $0, remoteID: $1, dog: dog)) }
        )
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
                context.delete(entry)
            }
        }
    }
}

// MARK: - Protokoll som gör den modulvisa mergen generisk

protocol SyncableEntry: PersistentModel {
    var remoteID: UUID? { get }
    var updatedAt: Date? { get }
    var pendingUpload: Bool { get }
}

protocol SyncableDTO {
    var updatedAt: Date { get }
}

extension HealthEvent: SyncableEntry {}
extension HeatCycle: SyncableEntry {}
extension DiaryEntry: SyncableEntry {}
extension MealEntry: SyncableEntry {}
extension TrainingSession: SyncableEntry {}

extension HealthEventDTO: SyncableDTO {}
extension HeatCycleDTO: SyncableDTO {}
extension DiaryEntryDTO: SyncableDTO {}
extension MealEntryDTO: SyncableDTO {}
extension TrainingSessionDTO: SyncableDTO {}
