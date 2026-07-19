//
//  DogRestoreService.swift
//  UppdragHund
//
//  Återställer egna hundar från molnet efter t.ex. en ominstallation.
//  Egna hundar lagras lokalt i SwiftData; det som speglas till molnet är
//  profilens dogSummaries (grunduppgifter) och — för delade hundar — hela
//  hunddokumentet med loggdata. Denna tjänst väver ihop båda källorna.
//

import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
enum DogRestoreService {
    struct Result {
        var created: Int = 0
        var enrichedFromShare: Int = 0
    }

    /// Alla hund-remoteID:n som går att återställa från molnet men saknas
    /// lokalt — union av profilens summeringar och hundar man delat ut.
    static func restorableIDs(uid: String, localRemoteIDs: Set<String>) async -> Set<String> {
        var ids = Set<String>()
        if let summaries = try? await FriendsRepository.shared.fetchMyProfile(uid: uid)?.dogSummaries {
            ids.formUnion(summaries.map(\.remoteID))
        }
        if let shares = try? await SharingRepository.shared.sharesIOwn(ownerUid: uid) {
            ids.formUnion(shares.map(\.dogRemoteID))
        }
        return ids.subtracting(localRemoteIDs)
    }

    /// Återskapar hundar som finns i molnet men saknas lokalt. Bevarar
    /// remoteID så delningskopplingar hålls intakta. Delade hundar får
    /// full loggdata; övriga får grunduppgifter från summeringen.
    static func restore(context: ModelContext, uid: String) async throws -> Result {
        let summaries = (try? await FriendsRepository.shared.fetchMyProfile(uid: uid)?.dogSummaries) ?? []
        let summaryByID = Dictionary(summaries.map { ($0.remoteID, $0) }, uniquingKeysWith: { first, _ in first })
        let shares = (try? await SharingRepository.shared.sharesIOwn(ownerUid: uid)) ?? []

        let existing = try context.fetch(FetchDescriptor<Dog>(predicate: #Predicate { !$0.isShared }))
        let existingIDs = Set(existing.compactMap { $0.remoteID?.uuidString })

        let allIDs = Set(summaries.map(\.remoteID)).union(shares.map(\.dogRemoteID)).subtracting(existingIDs)

        var result = Result()

        for idString in allIDs {
            guard let remoteID = UUID(uuidString: idString) else { continue }

            let dog = Dog(name: "", breed: "", birthDate: .now, sex: .female)
            dog.remoteID = remoteID
            dog.ownerUid = uid
            dog.isShared = false

            // Full återställning om hunden var delad (hela dokumentet + loggar).
            let enriched = try await enrichFromShareIfPossible(dog: dog, remoteID: idString, ownerUid: uid, context: context)
            if enriched { result.enrichedFromShare += 1 }

            // Fyll i från summeringen om delningsdata saknades (eller komplettera).
            if let s = summaryByID[idString] {
                if dog.name.isEmpty { dog.name = s.name }
                if dog.breed.isEmpty { dog.breed = s.breed }
                if !enriched {
                    dog.birthDate = s.birthDate
                    dog.sex = DogSex(rawValue: s.sex) ?? .female
                    dog.photoData = s.photoData
                }
                dog.passedAwayDate = s.isDeceased == true ? s.deceasedDate : dog.passedAwayDate
                dog.hdResult = dog.hdResult ?? s.hdResult
                dog.edResult = dog.edResult ?? s.edResult
                dog.mentalTestDone = dog.mentalTestDone || (s.mentalTest ?? false)
                dog.showMerit = dog.showMerit || (s.showMerit ?? false)
                dog.vaccinated = dog.vaccinated || (s.vaccinated ?? false)
            }

            // Skippa helt tomma skal (ingen källa gav data).
            if dog.name.isEmpty && dog.breed.isEmpty && !enriched {
                context.delete(dog)
                continue
            }
            result.created += 1
        }

        try context.save()
        return result
    }

    /// Om ett sharedDogs-dokument finns: applicera fulla profilfält och
    /// återställ loggposterna (hälsa/löp/dagbok/foder/träning).
    private static func enrichFromShareIfPossible(dog: Dog, remoteID: String, ownerUid: String, context: ModelContext) async throws -> Bool {
        let repository = SharingRepository.shared
        guard let doc = try? await repository.fetchDogDoc(dogRemoteID: remoteID) else { return false }
        ShareMapping.apply(doc, to: dog)
        dog.isShared = false          // Detta är ägarens egen hund.
        dog.ownerUid = ownerUid

        for module in SharedModule.allCases {
            guard let documents = try? await repository.fetchEntryDocuments(dogRemoteID: remoteID, module: module) else { continue }
            for (id, snapshot) in documents {
                guard let entryID = UUID(uuidString: id) else { continue }
                switch module {
                case .health:
                    if let dto = try? snapshot.data(as: HealthEventDTO.self) {
                        context.insert(ShareMapping.makeHealthEvent(from: dto, remoteID: entryID, dog: dog))
                    }
                case .heat:
                    if let dto = try? snapshot.data(as: HeatCycleDTO.self) {
                        context.insert(ShareMapping.makeHeatCycle(from: dto, remoteID: entryID, dog: dog))
                    }
                case .diary:
                    if let dto = try? snapshot.data(as: DiaryEntryDTO.self) {
                        context.insert(ShareMapping.makeDiaryEntry(from: dto, remoteID: entryID, dog: dog))
                    }
                case .meals:
                    if let dto = try? snapshot.data(as: MealEntryDTO.self) {
                        context.insert(ShareMapping.makeMealEntry(from: dto, remoteID: entryID, dog: dog))
                    }
                case .training:
                    if let dto = try? snapshot.data(as: TrainingSessionDTO.self) {
                        context.insert(ShareMapping.makeTrainingSession(from: dto, remoteID: entryID, dog: dog))
                    }
                }
            }
        }
        return true
    }
}
