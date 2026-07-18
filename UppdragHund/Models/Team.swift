//
//  Team.swift
//  UppdragHund
//
//  Team (grupper av vänner) och hundträffar. Lagras i Firestore under
//  toppnivåkollektionerna teams/ och meetups/.
//

import Foundation
import FirebaseFirestore

/// Typ av team — styr vilka funktioner som visas. En promenadgrupp ska
/// inte mötas av uppgifter och konsulentroller.
enum TeamKind: String, CaseIterable, Identifiable {
    /// Konsulent som coachar kunder löpande — full funktionalitet.
    case consulting
    /// Hundkurs med kursdeltagare — allt + inbjudningskod för gruppen.
    case course
    /// Vanlig grupp (t.ex. promenadgäng) — bara inlägg och träffar.
    case social

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .consulting: String(localized: "Konsulentverksamhet")
        case .course: String(localized: "Hundkurs")
        case .social: String(localized: "Vanlig grupp")
        }
    }

    var description: String {
        switch self {
        case .consulting: String(localized: "Coacha dina kunder med uppgifter, träningspass och träffar.")
        case .course: String(localized: "Kursgrupp med uppgifter, hemläxor och inbjudningskod till deltagarna.")
        case .social: String(localized: "Dela inlägg och planera träffar — t.ex. ett promenadgäng.")
        }
    }

    var icon: String {
        switch self {
        case .consulting: "person.badge.shield.checkmark"
        case .course: "graduationcap.fill"
        case .social: "figure.walk"
        }
    }

    /// Uppgifter/hemläxor och konsulentroller.
    var hasTasks: Bool { self != .social }
    /// Inbjudningskod för att få in en hel kursgrupp.
    var hasJoinCode: Bool { self == .course }
}

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
    /// Teamets profilbild (liten JPEG, Firestore Blob). Sätts av ägaren.
    var photoData: Data?
    /// Teamtyp (rå sträng för framtidssäker avkodning). Team skapade innan
    /// fältet fanns behandlas som konsulentverksamhet — full funktionalitet.
    var teamType: String?

    var kind: TeamKind { TeamKind(rawValue: teamType ?? "") ?? .consulting }

    var memberCount: Int { memberUids.count }

    func isConsultant(_ uid: String?) -> Bool {
        guard let uid else { return false }
        return (consultantUids ?? []).contains(uid)
    }

    /// Ägaren och konsulenter får skapa uppgifter till teamet.
    func canManageTasks(_ uid: String?) -> Bool {
        uid == ownerUid || isConsultant(uid)
    }

    /// Vem får skapa träffar? I kurser/konsulentteam bara ägare/konsulenter
    /// (deltagare ska inte lägga in egna kurstillfällen); i vanliga grupper
    /// alla medlemmar. Speglas i säkerhetsreglerna.
    func canCreateMeetups(_ uid: String?) -> Bool {
        guard let uid, memberUids.contains(uid) else { return false }
        return kind == .social || canManageTasks(uid)
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
    /// Valfritt kopplat träningspass (samma delningsformat som inlägg).
    var trainingPlan: SharedTrainingPlan?
    /// Valfri kopplad träff. Titel/datum cachas så uppgiften kan visa
    /// träffen utan extra uppslag (och även om träffen senare tas bort).
    var meetupId: String?
    var meetupTitle: String?
    var meetupDate: Date?

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
    /// Öppen stadsträff: hör till en community i stället för ett team. Då är
    /// träffen synlig och RSVP-bar för alla stadens medlemmar, utan att var och
    /// en behöver bjudas in (invitedUids skalar inte till en hel stad).
    /// Optional så att träffar skapade före fältet fanns fortfarande avkodas.
    var communityId: String?
    var communityName: String?
    var invitedUids: [String]
    /// uid -> visningsnamn för alla inblandade (ägare + inbjudna).
    var invitedNames: [String: String]
    var goingUids: [String]
    var declinedUids: [String]
    var createdAt: Date
    /// Kartnål (valfri, sätts via platssökning eller tryck på kartan).
    var latitude: Double?
    var longitude: Double?
    /// Kursserie: flera tillfällen skapade tillsammans delar seriesId.
    var seriesId: String?
    var seriesIndex: Int?
    var seriesCount: Int?
    /// Max antal platser (nil = obegränsat).
    var maxSpots: Int?
    /// Närvaro — bockas av av ägaren per tillfälle.
    var attendedUids: [String]?

    func rsvp(for uid: String) -> MeetupRSVP {
        if goingUids.contains(uid) { return .going }
        if declinedUids.contains(uid) { return .declined }
        return .pending
    }

    /// "Tillfälle 3 av 8" för kursserier.
    var seriesLabel: String? {
        guard let seriesIndex, let seriesCount, seriesCount > 1 else { return nil }
        return String(localized: "Tillfälle \(seriesIndex) av \(seriesCount)")
    }

    var isFull: Bool {
        guard let maxSpots, maxSpots > 0 else { return false }
        return goingUids.count >= maxSpots
    }

    func didAttend(_ uid: String) -> Bool {
        (attendedUids ?? []).contains(uid)
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
