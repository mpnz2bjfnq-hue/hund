//
//  CommunitiesRepository.swift
//  UppdragHund
//
//  Firestore-åtkomst för öppna stadsgrupper. Samma stil som övriga
//  repositories: DTO in/ut, ingen vy-logik.
//
//  Städerna själva är statiska (Community.all) — här hanteras bara
//  medlemskapen under communities/{id}/members/{uid} och medlemsantalet.
//

import Foundation
import FirebaseFirestore

final class CommunitiesRepository {
    static let shared = CommunitiesRepository()

    private let db = Firestore.firestore()

    private init() {}

    private func membersRef(_ communityID: String) -> CollectionReference {
        db.collection("communities").document(communityID).collection("members")
    }

    /// Medlemsantal per stad. Läser den publika räknaren på varje community-
    /// dokument (memberCount), som hålls av en Cloud Function. Medlems-
    /// dokumenten själva är privata och går inte att räkna från klienten.
    /// En stad utan dokument (ingen har gått med än) räknas som 0.
    func memberCounts() async -> [String: Int] {
        let snapshot = try? await db.collection("communities").getDocuments()
        var counts: [String: Int] = [:]
        for document in snapshot?.documents ?? [] {
            counts[document.documentID] = document.data()["memberCount"] as? Int ?? 0
        }
        return counts
    }

    /// Vilka städer användaren redan är med i. Slår upp det egna
    /// medlemsdokumentet i varje stad direkt (dokument-ID = uid) — tio punkt-
    /// läsningar, inga index och ingen collectionGroup-fråga.
    func myMemberships(uid: String) async -> Set<String> {
        var joined: Set<String> = []
        await withTaskGroup(of: (String, Bool).self) { group in
            for community in Community.all {
                group.addTask { [membersRef] in
                    let doc = try? await membersRef(community.id).document(uid).getDocument()
                    return (community.id, doc?.exists == true)
                }
            }
            for await (id, isMember) in group {
                if isMember { joined.insert(id) }
            }
        }
        return joined
    }

    func isMember(communityID: String, uid: String) async -> Bool {
        let doc = try? await membersRef(communityID).document(uid).getDocument()
        return doc?.exists == true
    }

    /// Gå med: skriv sitt eget medlemsdokument. Reglerna tillåter bara att man
    /// skapar dokumentet vars ID är den egna uid:n, så ingen kan lägga till
    /// någon annan.
    func join(communityID: String, uid: String, displayName: String) async throws {
        let member = CommunityMember(uid: uid, displayName: displayName, joinedAt: .now)
        try membersRef(communityID).document(uid).setData(from: member)
    }

    func leave(communityID: String, uid: String) async throws {
        try await membersRef(communityID).document(uid).delete()
    }
}
