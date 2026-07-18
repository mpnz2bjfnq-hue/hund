//
//  SharingRepository.swift
//  UppdragHund
//
//  Firestore-åtkomst för delade hundar. Medvetet logikfritt lager:
//  tar och returnerar DTO:er, ingen SwiftData-kunskap. All merge-/difflogik
//  bor i rena, testbara typer (SyncPlanner, ShareMapping).
//

import Foundation
import FirebaseFirestore

final class SharingRepository {
    static let shared = SharingRepository()

    private let db = Firestore.firestore()
    private static let batchLimit = 450 // Firestore-tak är 500 operationer per batch

    private init() {}

    private func dogRef(_ dogRemoteID: String) -> DocumentReference {
        db.collection("sharedDogs").document(dogRemoteID)
    }

    private func moduleCollection(_ dogRemoteID: String, _ module: SharedModule) -> CollectionReference {
        dogRef(dogRemoteID).collection(module.collectionName)
    }

    // MARK: - Shares

    func upsertShare(_ share: ShareDoc) async throws {
        try db.collection("shares").document(share.documentID).setData(from: share)
    }

    func deleteShare(dogRemoteID: String, recipientUid: String) async throws {
        let id = ShareDoc.documentID(dogRemoteID: dogRemoteID, recipientUid: recipientUid)
        try await db.collection("shares").document(id).delete()
    }

    func sharesIOwn(ownerUid: String) async throws -> [ShareDoc] {
        let snapshot = try await db.collection("shares")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ShareDoc.self) }
    }

    /// OBS: ownerUid-filtret är inte bara semantik — säkerhetsreglerna kan
    /// bara bevisa en query som filtrerar på ägare eller mottagare. Utan det
    /// nekas hela frågan av Firestore.
    func shares(forDog dogRemoteID: String, ownerUid: String) async throws -> [ShareDoc] {
        let snapshot = try await db.collection("shares")
            .whereField("ownerUid", isEqualTo: ownerUid)
            .whereField("dogRemoteID", isEqualTo: dogRemoteID)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ShareDoc.self) }
    }

    func sharesWithMe(recipientUid: String) async throws -> [ShareDoc] {
        let snapshot = try await db.collection("shares")
            .whereField("recipientUid", isEqualTo: recipientUid)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ShareDoc.self) }
    }

    // MARK: - Dog document

    func upsertDogDoc(dogRemoteID: String, doc: SharedDogDoc) async throws {
        try dogRef(dogRemoteID).setData(from: doc)
    }

    func fetchDogDoc(dogRemoteID: String) async throws -> SharedDogDoc? {
        let snapshot = try await dogRef(dogRemoteID).getDocument()
        guard snapshot.exists else { return nil }
        return try? snapshot.data(as: SharedDogDoc.self)
    }

    /// Firestore-klienten har ingen rekursiv delete — subkollektionerna
    /// måste tömmas explicit innan hunddokumentet och dess shares tas bort.
    func deleteDogCompletely(dogRemoteID: String, ownerUid: String) async throws {
        for module in SharedModule.allCases {
            try await deleteAllEntries(dogRemoteID: dogRemoteID, module: module)
        }
        for share in try await shares(forDog: dogRemoteID, ownerUid: ownerUid) {
            try await db.collection("shares").document(share.documentID).delete()
        }
        try await dogRef(dogRemoteID).delete()
    }

    // MARK: - Module entries

    /// Skriver dokument batchat. `docs` mappar dokument-ID -> Encodable DTO.
    func upsertEntries(dogRemoteID: String, module: SharedModule, docs: [String: Encodable]) async throws {
        let collection = moduleCollection(dogRemoteID, module)
        for chunk in Array(docs).chunked(into: Self.batchLimit) {
            let batch = db.batch()
            for (id, dto) in chunk {
                try batch.setData(from: dto, forDocument: collection.document(id))
            }
            try await batch.commit()
        }
    }

    func deleteEntries(dogRemoteID: String, module: SharedModule, ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        let collection = moduleCollection(dogRemoteID, module)
        for chunk in ids.chunked(into: Self.batchLimit) {
            let batch = db.batch()
            for id in chunk {
                batch.deleteDocument(collection.document(id))
            }
            try await batch.commit()
        }
    }

    func fetchEntryDocuments(dogRemoteID: String, module: SharedModule) async throws -> [(id: String, snapshot: DocumentSnapshot)] {
        let snapshot = try await moduleCollection(dogRemoteID, module).getDocuments()
        return snapshot.documents.map { ($0.documentID, $0) }
    }

    func deleteAllEntries(dogRemoteID: String, module: SharedModule) async throws {
        let snapshot = try await moduleCollection(dogRemoteID, module).getDocuments()
        try await deleteEntries(dogRemoteID: dogRemoteID, module: module, ids: snapshot.documents.map(\.documentID))
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
