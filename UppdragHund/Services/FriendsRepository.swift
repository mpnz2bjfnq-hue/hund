//
//  FriendsRepository.swift
//  UppdragHund
//

import Foundation
import FirebaseFirestore

final class FriendsRepository {
    static let shared = FriendsRepository()

    private let db = Firestore.firestore()

    private init() {}

    func ensureProfile(uid: String, displayName: String, email: String?) async throws {
        let ref = db.collection("users").document(uid)
        let snapshot = try await ref.getDocument()
        if snapshot.exists {
            return
        }
        let handle = try await generateUniqueHandle()
        let profile = UserProfile(displayName: displayName, handle: handle, email: email, createdAt: .now)
        try ref.setData(from: profile)
    }

    func fetchMyProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UserProfile.self)
    }

    func sendFriendRequest(from myUid: String, myDisplayName: String, myHandle: String, toHandle: String) async throws {
        let query = db.collection("users").whereField("handle", isEqualTo: toHandle)
        let snapshot = try await query.getDocuments()
        guard let targetDoc = snapshot.documents.first else {
            throw FriendsError.userNotFound
        }
        let toUid = targetDoc.documentID
        guard toUid != myUid else {
            throw FriendsError.cannotAddSelf
        }

        let existingFriend = try await db.collection("users").document(myUid)
            .collection("friends").document(toUid).getDocument()
        guard !existingFriend.exists else {
            throw FriendsError.alreadyFriends
        }

        let request = FriendRequest(
            fromUid: myUid,
            fromDisplayName: myDisplayName,
            fromHandle: myHandle,
            toUid: toUid,
            status: .pending,
            createdAt: .now
        )
        _ = try db.collection("friendRequests").addDocument(from: request)
    }

    func pendingRequests(for uid: String) async throws -> [FriendRequest] {
        let snapshot = try await db.collection("friendRequests")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: FriendRequest.self) }
    }

    func respondToRequest(_ request: FriendRequest, accept: Bool) async throws {
        guard let id = request.id else { return }
        let newStatus: FriendRequestStatus = accept ? .accepted : .declined
        try await db.collection("friendRequests").document(id).updateData(["status": newStatus.rawValue])

        if accept {
            try await db.collection("users").document(request.toUid)
                .collection("friends").document(request.fromUid)
                .setData(["since": Date()])
            try await db.collection("users").document(request.fromUid)
                .collection("friends").document(request.toUid)
                .setData(["since": Date()])
        }
    }

    func friends(for uid: String) async throws -> [UserProfile] {
        let snapshot = try await db.collection("users").document(uid).collection("friends").getDocuments()
        var profiles: [UserProfile] = []
        for document in snapshot.documents {
            let friendSnapshot = try await db.collection("users").document(document.documentID).getDocument()
            if friendSnapshot.exists, let profile = try? friendSnapshot.data(as: UserProfile.self) {
                profiles.append(profile)
            }
        }
        return profiles
    }

    private func generateUniqueHandle() async throws -> String {
        for _ in 0..<5 {
            let candidate = Self.randomHandle()
            let existing = try await db.collection("users").whereField("handle", isEqualTo: candidate).getDocuments()
            if existing.documents.isEmpty {
                return candidate
            }
        }
        return Self.randomHandle()
    }

    private static func randomHandle() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let suffix = String((0..<5).map { _ in chars.randomElement()! })
        return "DOG-\(suffix)"
    }

    enum FriendsError: LocalizedError {
        case userNotFound
        case cannotAddSelf
        case alreadyFriends

        var errorDescription: String? {
            switch self {
            case .userNotFound: "Ingen användare hittades med den koden."
            case .cannotAddSelf: "Du kan inte lägga till dig själv som vän."
            case .alreadyFriends: "Ni är redan vänner."
            }
        }
    }
}
