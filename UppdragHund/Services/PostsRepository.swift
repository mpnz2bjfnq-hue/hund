//
//  PostsRepository.swift
//  UppdragHund
//
//  Firestore-åtkomst för profilinlägg. Samma stil som FriendsRepository.
//

import Foundation
import FirebaseFirestore

final class PostsRepository {
    static let shared = PostsRepository()

    private let db = Firestore.firestore()

    private init() {}

    private func postsCollection(uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("posts")
    }

    func createPost(
        authorUid: String,
        authorName: String,
        text: String,
        dogRemoteID: String? = nil,
        dogName: String? = nil
    ) async throws {
        let post = ProfilePost(
            authorUid: authorUid,
            authorName: authorName,
            text: text,
            createdAt: .now,
            dogRemoteID: dogRemoteID,
            dogName: dogName
        )
        _ = try postsCollection(uid: authorUid).addDocument(from: post)
    }

    func deletePost(authorUid: String, postID: String) async throws {
        try await postsCollection(uid: authorUid).document(postID).delete()
    }

    func posts(forUid uid: String) async throws -> [ProfilePost] {
        let snapshot = try await postsCollection(uid: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ProfilePost.self) }
    }

    func postCount(forUid uid: String) async throws -> Int {
        let snapshot = try await postsCollection(uid: uid).count.getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
}
