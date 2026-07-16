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
    /// Medlemmar med titeln Konsulent (utsedda av ägaren). Optional så att
    /// team skapade före fältet fanns fortfarande kan avkodas.
    var consultantUids: [String]?

    var memberCount: Int { memberUids.count }

    func isConsultant(_ uid: String?) -> Bool {
        guard let uid else { return false }
        return (consultantUids ?? []).contains(uid)
    }

    /// Ägaren och konsulenter får skapa uppgifter till teamet.
    func canManageTasks(_ uid: String?) -> Bool {
        uid == ownerUid || isConsultant(uid)
    }
}

/// Uppgift som en konsulent (eller ägaren) lägger ut till teamet.
/// Lagras under teams/{teamId}/tasks. Varje medlem bockar av sig själv
/// i completedUids så alla ser vilka som är klara.
struct TeamTask: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var title: String
    var note: String?
    var dueDate: Date?
    var createdByUid: String
    var createdByName: String
    var createdAt: Date
    var completedUids: [String]

    func isCompleted(by uid: String?) -> Bool {
        guard let uid else { return false }
        return completedUids.contains(uid)
    }
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
    /// Kartnål (valfri, sätts via platssökning eller tryck på kartan).
    var latitude: Double?
    var longitude: Double?

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
