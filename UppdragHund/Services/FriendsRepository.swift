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

        // Redan en giltig profil? (Har både namn och användarnamn.)
        if snapshot.exists,
           let existingName = snapshot.get("displayName") as? String, !existingName.isEmpty,
           let existingHandle = snapshot.get("handle") as? String, !existingHandle.isEmpty {
            return
        }

        // Skapa eller REPARERA. Ett halvt dokument kan ha uppstått om t.ex.
        // dogSummaries skrevs innan profilen fanns. Behåll ett ev. befintligt
        // handle och merge:a så vi inte tappar dogSummaries/photoData.
        let handle: String
        if let existingHandle = snapshot.get("handle") as? String, !existingHandle.isEmpty {
            handle = existingHandle
        } else {
            handle = try await generateUniqueHandle()
        }
        let existingCreatedAt = (snapshot.get("createdAt") as? Timestamp)?.dateValue()
        let profile = UserProfile(
            displayName: displayName,
            handle: handle,
            email: email,
            createdAt: existingCreatedAt ?? .now
        )
        // Handle-claim + profilskrivning atomiskt — reglerna kräver (via
        // getAfter) att ett nytt/ändrat handle är registrerat på skrivaren.
        let batch = db.batch()
        try await stageHandleClaim(handle, releasing: nil, uid: uid, in: batch)
        try batch.setData(from: profile, forDocument: ref, merge: true)
        try await batch.commit()
    }

    /// Speglar appens språk till profilen så Cloud Functions kan skicka pushar
    /// på rätt språk (utan fältet faller servern tillbaka på svenska).
    /// Skrivs vid varje inloggning — språket kan bytas i iOS-inställningarna.
    func updateLanguage(uid: String) async {
        // Bundle.main, inte Locale.current: vi vill ha språket appen faktiskt
        // körs på, inte enhetens regioninställning.
        let code = Bundle.main.preferredLocalizations.first?.prefix(2).lowercased() ?? "sv"
        let language = code == "en" ? "en" : "sv"
        try? await db.collection("users").document(uid).setData(["language": language], merge: true)
    }

    func fetchMyProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: UserProfile.self)
    }

    /// Är användarnamnet ledigt? Ett namn som redan tillhör `excludingUid`
    /// (dvs. mitt eget nuvarande) räknas som ledigt.
    /// Kollar BÅDE handle-registret (hård garanti, dokument-ID = handle) och
    /// users-frågan (skyddsnät för konton från innan registret fanns).
    func isUsernameAvailable(_ handle: String, excludingUid: String) async throws -> Bool {
        let registered = try await db.collection("handles").document(handle).getDocument()
        if registered.exists, (registered.get("uid") as? String) != excludingUid {
            return false
        }
        let snapshot = try await db.collection("users")
            .whereField("handle", isEqualTo: handle)
            .getDocuments()
        return snapshot.documents.allSatisfy { $0.documentID == excludingUid }
    }

    /// Lägger claim + ev. frisläppning av gammalt handle i `batch`. Kastar
    /// handleTaken om registret säger att någon annan äger namnet. Själva
    /// unikheten garanteras av att dokument-ID:t ÄR handlet — två samtidiga
    /// batchar om samma namn kan inte båda lyckas (reglerna kräver via
    /// getAfter att profilens handle är registrerat på skrivaren).
    private func stageHandleClaim(
        _ handle: String,
        releasing oldHandle: String?,
        uid: String,
        in batch: WriteBatch
    ) async throws {
        let handleRef = db.collection("handles").document(handle)
        let existing = try await handleRef.getDocument()
        if existing.exists {
            guard (existing.get("uid") as? String) == uid else {
                throw FriendsError.handleTaken
            }
        } else {
            batch.setData(["uid": uid], forDocument: handleRef)
        }
        if let oldHandle, oldHandle != handle {
            let oldRef = db.collection("handles").document(oldHandle)
            let oldDoc = try await oldRef.getDocument()
            // Radera bara ett registrerat namn som är MITT — delete av ett
            // saknat dokument skulle dessutom fälla hela batchen i reglerna.
            if oldDoc.exists, (oldDoc.get("uid") as? String) == uid {
                batch.deleteDocument(oldRef)
            }
        }
    }

    /// Uppdaterar redigerbara profilfält. Skickar bara med fält som ändras.
    /// Vid handle-byte MÅSTE `currentHandle` skickas med så det gamla namnet
    /// släpps i registret; bytet sker atomiskt i en batch.
    func updateProfile(
        uid: String,
        displayName: String? = nil,
        handle: String? = nil,
        currentHandle: String? = nil,
        photoData: Data?? = nil,
        coverPhotoData: Data?? = nil,
        bio: String?? = nil,
        favoritePhotoDatas: [Data]?? = nil
    ) async throws {
        var data: [String: Any] = [:]
        if let displayName { data["displayName"] = displayName }
        if let handle { data["handle"] = handle }
        if let photoData {
            // photoData == .some(nil) betyder "ta bort bilden".
            data["photoData"] = photoData ?? FieldValue.delete()
        }
        if let coverPhotoData {
            data["coverPhotoData"] = coverPhotoData ?? FieldValue.delete()
        }
        if let bio {
            data["bio"] = (bio?.isEmpty == false ? bio : nil) ?? FieldValue.delete()
        }
        if let favoritePhotoDatas {
            data["favoritePhotoDatas"] = (favoritePhotoDatas?.isEmpty == false ? favoritePhotoDatas : nil) ?? FieldValue.delete()
        }
        guard !data.isEmpty else { return }
        let userRef = db.collection("users").document(uid)
        if let handle {
            let batch = db.batch()
            try await stageHandleClaim(handle, releasing: currentHandle, uid: uid, in: batch)
            batch.setData(data, forDocument: userRef, merge: true)
            try await batch.commit()
        } else {
            try await userRef.setData(data, merge: true)
        }
    }

    /// Räknar mina vänner (exakt, ur den privata vänlistan). Det publika
    /// friendCount-fältet skrivs numera ENBART av servern (onFriendsChanged)
    /// — klienten är spärrad i reglerna så antalet inte kan förfalskas.
    func syncFriendCount(uid: String) async throws -> Int {
        try await db.collection("users").document(uid)
            .collection("friends").count.getAggregation(source: .server)
            .count.intValue
    }

    /// Prefix-sökning på @handle och visningsnamn — för live-förslag när man
    /// lägger till vänner. Firestore saknar substrings, så det är "börjar med".
    func searchUsers(matching query: String, excludingUid: String, limit: Int = 8) async -> [UserProfile] {
        let trimmed = query
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "@", with: "")
        guard trimmed.count >= 2 else { return [] }
        let end = trimmed + "\u{f8ff}"

        async let byHandle = try? db.collection("users")
            .whereField("handle", isGreaterThanOrEqualTo: trimmed)
            .whereField("handle", isLessThan: end)
            .limit(to: limit)
            .getDocuments()
        async let byName = try? db.collection("users")
            .whereField("displayName", isGreaterThanOrEqualTo: trimmed)
            .whereField("displayName", isLessThan: end)
            .limit(to: limit)
            .getDocuments()

        let docs = (await byHandle?.documents ?? []) + (await byName?.documents ?? [])
        var seen = Set<String>()
        return docs.compactMap { doc -> UserProfile? in
            guard doc.documentID != excludingUid, !seen.contains(doc.documentID) else { return nil }
            seen.insert(doc.documentID)
            return try? doc.data(as: UserProfile.self)
        }
    }

    func sendFriendRequest(from myUid: String, myDisplayName: String, myHandle: String, toHandle: String) async throws {
        let query = db.collection("users").whereField("handle", isEqualTo: toHandle)
        let snapshot = try await query.getDocuments()
        guard let targetDoc = snapshot.documents.first else {
            throw FriendsError.userNotFound
        }
        try await sendFriendRequest(from: myUid, myDisplayName: myDisplayName, myHandle: myHandle, toUid: targetDoc.documentID)
    }

    /// Skickar en vänförfrågan direkt till ett uid — används när man redan
    /// står på personens profil (t.ex. en teammedlem man inte är vän med).
    func sendFriendRequest(from myUid: String, myDisplayName: String, myHandle: String, toUid: String) async throws {
        guard toUid != myUid else {
            throw FriendsError.cannotAddSelf
        }

        let existingFriend = try await db.collection("users").document(myUid)
            .collection("friends").document(toUid).getDocument()
        guard !existingFriend.exists else {
            throw FriendsError.alreadyFriends
        }

        // Skicka inte dubbletter — mottagaren skulle annars få identiska
        // förfrågningar att besvara en och en.
        let outbound = try await db.collection("friendRequests")
            .whereField("fromUid", isEqualTo: myUid)
            .whereField("toUid", isEqualTo: toUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        guard outbound.isEmpty else { return }

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

    /// Vänskapsläget mellan mig och en annan användare — styr vilken knapp
    /// profilen visar. Frågorna är formade så reglerna kan bevisa dem
    /// (egna friends-subkollektionen + friendRequests filtrerade på mitt uid).
    func friendshipStatus(myUid: String, otherUid: String) async -> FriendshipStatus {
        guard myUid != otherUid else { return .ownProfile }

        if let doc = try? await db.collection("users").document(myUid)
            .collection("friends").document(otherUid).getDocument(), doc.exists {
            return .friends
        }

        let outbound = try? await db.collection("friendRequests")
            .whereField("fromUid", isEqualTo: myUid)
            .whereField("toUid", isEqualTo: otherUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        if outbound?.isEmpty == false { return .requestSent }

        let inbound = try? await db.collection("friendRequests")
            .whereField("toUid", isEqualTo: myUid)
            .whereField("fromUid", isEqualTo: otherUid)
            .whereField("status", isEqualTo: FriendRequestStatus.pending.rawValue)
            .limit(to: 1)
            .getDocuments()
        if inbound?.isEmpty == false { return .requestReceived }

        return .notFriends
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

    /// Tar bort vänskapen åt båda håll. Vänräknarna läker via onFriendsChanged.
    func removeFriend(myUid: String, friendUid: String) async throws {
        try await db.collection("users").document(myUid)
            .collection("friends").document(friendUid).delete()
        try await db.collection("users").document(friendUid)
            .collection("friends").document(myUid).delete()
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

    /// Vänskapsläget mellan mig och en annan användare.
    enum FriendshipStatus {
        case ownProfile
        case friends
        case requestSent
        case requestReceived
        case notFriends
    }

    enum FriendsError: LocalizedError {
        case userNotFound
        case cannotAddSelf
        case alreadyFriends
        case handleTaken

        var errorDescription: String? {
            switch self {
            case .userNotFound: String(localized: "Ingen användare hittades med den koden.")
            case .cannotAddSelf: String(localized: "Du kan inte lägga till dig själv som vän.")
            case .alreadyFriends: String(localized: "Ni är redan vänner.")
            case .handleTaken: String(localized: "Användarnamnet är upptaget.")
            }
        }
    }
}
