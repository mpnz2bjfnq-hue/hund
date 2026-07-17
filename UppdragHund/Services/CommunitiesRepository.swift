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
            // Golva vid 0: en räknare kan tillfälligt vara negativ om den drivit
            // i otakt, tills funktionen räknat om den. Visa aldrig "-1 medlemmar".
            counts[document.documentID] = max(0, document.data()["memberCount"] as? Int ?? 0)
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

    // MARK: - Stadsträffar

    /// Kommande öppna träffar i en stad. Filtrerar på communityId (enkelt
    /// enfältsindex) och sorterar i klienten — inget sammansatt index behövs.
    func upcomingMeetups(communityID: String) async -> [Meetup] {
        let snapshot = try? await db.collection("meetups")
            .whereField("communityId", isEqualTo: communityID)
            .getDocuments()
        let cutoff = Calendar.current.date(byAdding: .hour, value: -6, to: .now) ?? .now
        return (snapshot?.documents.compactMap { try? $0.data(as: Meetup.self) } ?? [])
            .filter { $0.date > cutoff }
            .sorted { $0.date < $1.date }
    }

    /// Skapar en öppen stadsträff. Till skillnad från en team-/vänträff bjuds
    /// ingen in i förväg — den är synlig för hela stadens medlemmar.
    func createMeetup(
        community: Community,
        title: String,
        locationName: String,
        date: Date,
        ownerUid: String,
        ownerName: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        maxSpots: Int? = nil
    ) async throws {
        let meetup = Meetup(
            title: title,
            locationName: locationName,
            date: date,
            ownerUid: ownerUid,
            ownerName: ownerName,
            teamId: nil,
            teamName: nil,
            communityId: community.id,
            communityName: community.name,
            invitedUids: [],
            invitedNames: [ownerUid: ownerName],
            goingUids: [ownerUid],
            declinedUids: [],
            createdAt: .now,
            latitude: latitude,
            longitude: longitude,
            maxSpots: maxSpots
        )
        _ = try db.collection("meetups").addDocument(from: meetup)
    }
}
