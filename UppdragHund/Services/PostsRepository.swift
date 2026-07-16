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

    private func teamPostsCollection(teamId: String) -> CollectionReference {
        db.collection("teams").document(teamId).collection("posts")
    }

    /// Dokumentreferens för ett inlägg oavsett om det ligger på profilen
    /// eller i ett team.
    private func postDocument(for post: ProfilePost) -> DocumentReference? {
        guard let postID = post.id else { return nil }
        if let teamId = post.teamId {
            return teamPostsCollection(teamId: teamId).document(postID)
        }
        return postsCollection(uid: post.authorUid).document(postID)
    }

    func createPost(
        authorUid: String,
        authorName: String,
        text: String,
        dogRemoteID: String? = nil,
        dogName: String? = nil,
        trainingPlan: SharedTrainingPlan? = nil,
        photoData: Data? = nil,
        team: Team? = nil
    ) async throws {
        let post = ProfilePost(
            authorUid: authorUid,
            authorName: authorName,
            text: text,
            createdAt: .now,
            dogRemoteID: dogRemoteID,
            dogName: dogName,
            trainingPlan: trainingPlan,
            photoData: photoData,
            teamId: team?.id,
            teamName: team?.name
        )
        if let teamId = team?.id {
            _ = try teamPostsCollection(teamId: teamId).addDocument(from: post)
        } else {
            _ = try postsCollection(uid: authorUid).addDocument(from: post)
        }
    }

    func delete(post: ProfilePost) async throws {
        try await postDocument(for: post)?.delete()
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

    // MARK: - Team-inlägg

    func teamPosts(teamId: String) async -> [ProfilePost] {
        let snapshot = try? await teamPostsCollection(teamId: teamId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: ProfilePost.self) } ?? []
    }

    // MARK: - Reaktioner (🐾)

    func hasReacted(post: ProfilePost, uid: String) async -> Bool {
        guard let doc = postDocument(for: post) else { return false }
        let snap = try? await doc.collection("reactions").document(uid).getDocument()
        return snap?.exists ?? false
    }

    func setReaction(post: ProfilePost, uid: String, reacted: Bool) async throws {
        guard let doc = postDocument(for: post) else { return }
        let ref = doc.collection("reactions").document(uid)
        if reacted {
            try await ref.setData(["createdAt": FieldValue.serverTimestamp()])
        } else {
            try await ref.delete()
        }
    }

    func reactionCount(post: ProfilePost) async -> Int {
        guard let doc = postDocument(for: post) else { return 0 }
        let snap = try? await doc.collection("reactions").count.getAggregation(source: .server)
        return snap.map { Int(truncating: $0.count) } ?? 0
    }

    // MARK: - Kommentarer

    func comments(post: ProfilePost) async -> [PostComment] {
        guard let doc = postDocument(for: post) else { return [] }
        let snap = try? await doc.collection("comments")
            .order(by: "createdAt")
            .getDocuments()
        return snap?.documents.compactMap { try? $0.data(as: PostComment.self) } ?? []
    }

    func addComment(post: ProfilePost, authorUid: String, authorName: String, text: String) async throws {
        guard let doc = postDocument(for: post) else { return }
        let comment = PostComment(authorUid: authorUid, authorName: authorName, text: text, createdAt: .now)
        _ = try doc.collection("comments").addDocument(from: comment)
    }

    /// Kombinerat socialt flöde: inlägg från flera användare (jag + vänner)
    /// och mina team, parallellt hämtade och sorterade på tid.
    func feed(forUids uids: [String], teams: [Team] = [], limit: Int = 30) async -> [ProfilePost] {
        await withTaskGroup(of: [ProfilePost].self) { group in
            for uid in uids {
                group.addTask { (try? await self.posts(forUid: uid)) ?? [] }
            }
            for team in teams {
                if let teamId = team.id {
                    group.addTask { await self.teamPosts(teamId: teamId) }
                }
            }
            var all: [ProfilePost] = []
            for await chunk in group {
                all.append(contentsOf: chunk)
            }
            return Array(all.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
        }
    }
}
