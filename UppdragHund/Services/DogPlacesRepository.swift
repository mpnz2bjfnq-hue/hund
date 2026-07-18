//
//  DogPlacesRepository.swift
//  UppdragHund
//
//  Firestore-åtkomst för community-tipsade hundvänliga ställen.
//

import Foundation
import FirebaseFirestore

final class DogPlacesRepository {
    static let shared = DogPlacesRepository()

    private let db = Firestore.firestore()
    private var collection: CollectionReference { db.collection("dogPlaces") }

    private init() {}

    func add(_ place: DogPlace) async throws {
        try collection.addDocument(from: place)
    }

    /// Alla ställen. Geo-frågor kräver geohashing; för nuvarande skala hämtar
    /// vi allt och sorterar/filtrerar på avstånd i klienten.
    func all() async throws -> [DogPlace] {
        let snapshot = try await collection
            .order(by: "createdAt", descending: true)
            .limit(to: 500)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: DogPlace.self) }
    }

    /// Lägger till/tar bort den inloggade användarens rekommendation.
    /// Reglerna tillåter bara att man rör sitt EGET uid i recommendedBy.
    func toggleRecommend(placeID: String, uid: String, recommend: Bool) async throws {
        try await collection.document(placeID).updateData([
            "recommendedBy": recommend ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid])
        ])
    }

    func delete(placeID: String) async throws {
        try await collection.document(placeID).delete()
    }
}
