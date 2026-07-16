//
//  Team.swift
//  UppdragHund
//
//  Team (grupper av vänner) och hundträffar. Lagras i Firestore under
//  toppnivåkollektionerna teams/ och meetups/.
//

import Foundation
import FirebaseFirestore

struct Team: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var name: String
    var ownerUid: String
    var ownerName: String
    var memberUids: [String]
    /// uid -> visningsnamn, så medlemslistan kan visas utan extra uppslag.
    var memberNames: [String: String]
    var createdAt: Date

    var memberCount: Int { memberUids.count }
}

struct Meetup: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var title: String
    var locationName: String
    var date: Date
    var ownerUid: String
    var ownerName: String
    var teamId: String?
    var teamName: String?
    var invitedUids: [String]
    /// uid -> visningsnamn för alla inblandade (ägare + inbjudna).
    var invitedNames: [String: String]
    var goingUids: [String]
    var declinedUids: [String]
    var createdAt: Date

    func rsvp(for uid: String) -> MeetupRSVP {
        if goingUids.contains(uid) { return .going }
        if declinedUids.contains(uid) { return .declined }
        return .pending
    }
}

enum MeetupRSVP {
    case going, declined, pending
}

/// Inbjudan till ett team. Dokument-ID är alltid "{teamId}_{toUid}" så
/// säkerhetsreglerna kan slå upp den när mottagaren accepterar.
struct TeamInvite: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var teamId: String
    var teamName: String
    var fromUid: String
    var fromName: String
    var toUid: String
    var status: String   // "pending" / "accepted" / "declined"
    var createdAt: Date

    static func documentID(teamId: String, toUid: String) -> String {
        "\(teamId)_\(toUid)"
    }
}
