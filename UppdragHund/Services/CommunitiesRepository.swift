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

    /// Medlemsantal per stad, för alla städer på en gång. Läser en aggregerad
    /// räknare (count()) i stället för medlemsdokumenten — kostnaden blir en
    /// liten fast avgift per stad oavsett hur många medlemmar staden har.
    func memberCounts() async -> [String: Int] {
        var counts: [String: Int] = [:]
        await withTaskGroup(of: (String, Int).self) { group in
            for community in Community.all {
                group.addTask { [membersRef] in
                    let snapshot = try? await membersRef(community.id).count.getAggregation(source: .server)
                    return (community.id, snapshot?.count.intValue ?? 0)
                }
            }
            for await (id, count) in group {
                counts[id] = count
            }
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

    /// Medlemmarna i en stad, för medlemslistan. Begränsad sida — en stadsgrupp
    /// kan ha tusentals medlemmar, så vi hämtar aldrig alla på en gång.
    func members(communityID: String, limit: Int = 50) async -> [CommunityMember] {
        let snapshot = try? await membersRef(communityID)
            .order(by: "joinedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: CommunityMember.self) } ?? []
    }
}
