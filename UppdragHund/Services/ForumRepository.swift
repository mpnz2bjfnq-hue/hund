//
//  ForumRepository.swift
//  UppdragHund
//
//  Firestore-åtkomst för forumet (forum/ + forum/{id}/replies).
//

import Foundation
import FirebaseFirestore

final class ForumRepository {
    static let shared = ForumRepository()

    private let db = Firestore.firestore()

    private init() {}

    private var threads: CollectionReference { db.collection("forum") }

    private func replies(threadID: String) -> CollectionReference {
        threads.document(threadID).collection("replies")
    }

    /// Diskussioner, senast aktiva först.
    func allThreads(limit: Int = 100) async -> [ForumThread] {
        let snapshot = try? await threads
            .order(by: "lastActivityAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: ForumThread.self) } ?? []
    }

    func createThread(title: String, text: String, byUid: String, byName: String) async throws {
        let thread = ForumThread(
            title: title,
            text: text,
            authorUid: byUid,
            authorName: byName,
            createdAt: .now,
            replyCount: 0,
            lastActivityAt: .now
        )
        _ = try threads.addDocument(from: thread)
    }

    func replies(for threadID: String) async -> [ForumReply] {
        let snapshot = try? await replies(threadID: threadID)
            .order(by: "createdAt")
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: ForumReply.self) } ?? []
    }

    func addReply(threadID: String, text: String, byUid: String, byName: String) async throws {
        let reply = ForumReply(text: text, authorUid: byUid, authorName: byName, createdAt: .now)
        _ = try replies(threadID: threadID).addDocument(from: reply)
        // Denormaliserad räknare + aktivitet — reglerna tillåter bara just dessa fält.
        try await threads.document(threadID).updateData([
            "replyCount": FieldValue.increment(Int64(1)),
            "lastActivityAt": FieldValue.serverTimestamp(),
        ])
    }

    func deleteThread(_ threadID: String) async throws {
        // Svaren städas inte rekursivt från klienten (kräver admin) — men en
        // borttagen tråd utan förälder är oåtkomlig i UI:t och ofarlig.
        try await threads.document(threadID).delete()
    }

    func deleteReply(threadID: String, replyID: String) async throws {
        try await replies(threadID: threadID).document(replyID).delete()
        try await threads.document(threadID).updateData([
            "replyCount": FieldValue.increment(Int64(-1)),
        ])
    }
}
