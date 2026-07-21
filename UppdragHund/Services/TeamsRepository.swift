//
//  TeamsRepository.swift
//  UppdragHund
//
//  Firestore-åtkomst för team och hundträffar. Samma stil som övriga
//  repositories: DTO in/ut, ingen vy-logik.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class TeamsRepository {
    static let shared = TeamsRepository()

    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "europe-north1")

    private init() {}

    // MARK: - Inbjudningskod

    /// Teamets aktiva inbjudningskod, om en finns.
    func joinCode(teamID: String) async -> String? {
        let snapshot = try? await db.collection("teamJoinCodes").document(teamID).getDocument()
        guard snapshot?.data()?["active"] as? Bool == true else { return nil }
        return snapshot?.data()?["code"] as? String
    }

    /// Skapar (eller byter ut) teamets inbjudningskod. En kod per team —
    /// att generera en ny gör automatiskt den gamla ogiltig.
    func generateJoinCode(teamID: String, teamName: String) async throws -> String {
        // Utan lättförväxlade tecken (0/O, 1/I) — koden ska gå att läsa upp.
        let alphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")
        let code = String((0..<8).map { _ in alphabet.randomElement()! })
        try await db.collection("teamJoinCodes").document(teamID).setData([
            "code": code,
            "teamName": teamName,
            "active": true,
            "createdAt": FieldValue.serverTimestamp(),
        ])
        return code
    }

    /// Går med i ett team via inbjudningskod. Returnerar teamets namn.
    func joinTeam(code: String) async throws -> String {
        let result = try await functions.httpsCallable("joinTeamWithCode")
            .call(["code": code])
        let data = result.data as? [String: Any]
        return data?["teamName"] as? String ?? "teamet"
    }

    // MARK: - Team

    func createTeam(name: String, kind: TeamKind, ownerUid: String, ownerName: String) async throws {
        let team = Team(
            name: name,
            ownerUid: ownerUid,
            ownerName: ownerName,
            memberUids: [ownerUid],
            memberNames: [ownerUid: ownerName],
            createdAt: .now,
            teamType: kind.rawValue
        )
        _ = try db.collection("teams").addDocument(from: team)
    }

    func team(id: String) async -> Team? {
        let snapshot = try? await db.collection("teams").document(id).getDocument()
        return snapshot.flatMap { try? $0.data(as: Team.self) }
    }

    /// Enskild träff — används av notisdjuplänkarna (canine360://meetup?id=…).
    func meetup(id: String) async -> Meetup? {
        let snapshot = try? await db.collection("meetups").document(id).getDocument()
        return snapshot.flatMap { try? $0.data(as: Meetup.self) }
    }

    func myTeams(uid: String) async -> [Team] {
        let snapshot = try? await db.collection("teams")
            .whereField("memberUids", arrayContains: uid)
            .getDocuments()
        return (snapshot?.documents.compactMap { try? $0.data(as: Team.self) } ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    func addMember(teamID: String, uid: String, name: String) async throws {
        try await db.collection("teams").document(teamID).updateData([
            "memberUids": FieldValue.arrayUnion([uid]),
            "memberNames.\(uid)": name
        ])
    }

    /// Ägaren utser eller tar bort en konsulent.
    func setConsultant(teamID: String, uid: String, isConsultant: Bool) async throws {
        try await db.collection("teams").document(teamID).updateData([
            "consultantUids": isConsultant
                ? FieldValue.arrayUnion([uid])
                : FieldValue.arrayRemove([uid])
        ])
    }

    // MARK: - Uppgifter

    private func tasksCollection(teamID: String) -> CollectionReference {
        db.collection("teams").document(teamID).collection("tasks")
    }

    func tasks(teamID: String) async -> [TeamTask] {
        let snapshot = try? await tasksCollection(teamID: teamID)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: TeamTask.self) } ?? []
    }

    func createTask(
        teamID: String,
        title: String,
        note: String?,
        dueDate: Date?,
        byUid: String,
        byName: String,
        trainingPlan: SharedTrainingPlan? = nil,
        meetup: Meetup? = nil
    ) async throws {
        let task = TeamTask(
            title: title,
            note: note,
            dueDate: dueDate,
            createdByUid: byUid,
            createdByName: byName,
            createdAt: .now,
            completedUids: [],
            trainingPlan: trainingPlan,
            meetupId: meetup?.id,
            meetupTitle: meetup?.title,
            meetupDate: meetup?.date
        )
        _ = try tasksCollection(teamID: teamID).addDocument(from: task)
    }

    /// Redigerar en befintlig uppgift. Bevarar completedUids (avbockningar)
    /// och skaparen — bara innehållet och kopplingarna uppdateras.
    func updateTask(
        teamID: String,
        taskID: String,
        title: String,
        note: String?,
        dueDate: Date?,
        trainingPlan: SharedTrainingPlan? = nil,
        meetup: Meetup? = nil,
        keepExistingMeetup: Bool = false
    ) async throws {
        var data: [String: Any] = [
            "title": title,
            "note": note ?? FieldValue.delete(),
            "dueDate": dueDate.map { Timestamp(date: $0) } ?? FieldValue.delete()
        ]
        // keepExistingMeetup: träffkopplingen rörs inte alls — används när den
        // kopplade träffen passerat och därför inte går att välja i redigerings-
        // listan (annars skulle en textändring tyst radera kopplingen).
        if !keepExistingMeetup {
            data["meetupId"] = meetup?.id ?? FieldValue.delete()
            data["meetupTitle"] = meetup?.title ?? FieldValue.delete()
            data["meetupDate"] = meetup.map { Timestamp(date: $0.date) } ?? FieldValue.delete()
        }
        if let trainingPlan, let encoded = try? Firestore.Encoder().encode(trainingPlan) {
            data["trainingPlan"] = encoded
        } else {
            data["trainingPlan"] = FieldValue.delete()
        }
        try await tasksCollection(teamID: teamID).document(taskID).updateData(data)
    }

    func deleteTask(teamID: String, taskID: String) async throws {
        try await tasksCollection(teamID: teamID).document(taskID).delete()
    }

    /// Medlemmen bockar av (eller ångrar) sin egen del av uppgiften.
    func setTaskCompleted(teamID: String, taskID: String, uid: String, completed: Bool) async throws {
        try await tasksCollection(teamID: teamID).document(taskID).updateData([
            "completedUids": completed
                ? FieldValue.arrayUnion([uid])
                : FieldValue.arrayRemove([uid])
        ])
    }

    // MARK: - Inbjudningar

    func sendInvite(team: Team, toUid: String, fromUid: String, fromName: String) async throws {
        guard let teamId = team.id else { return }
        let invite = TeamInvite(
            teamId: teamId,
            teamName: team.name,
            fromUid: fromUid,
            fromName: fromName,
            toUid: toUid,
            status: "pending",
            createdAt: .now
        )
        try db.collection("teamInvites")
            .document(TeamInvite.documentID(teamId: teamId, toUid: toUid))
            .setData(from: invite)
    }

    func pendingInvites(for uid: String) async -> [TeamInvite] {
        let snapshot = try? await db.collection("teamInvites")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: TeamInvite.self) } ?? []
    }

    /// Har vännen redan en väntande inbjudan till teamet?
    func hasPendingInvite(teamId: String, toUid: String) async -> Bool {
        let doc = try? await db.collection("teamInvites")
            .document(TeamInvite.documentID(teamId: teamId, toUid: toUid))
            .getDocument()
        guard let doc, doc.exists else { return false }
        return (doc.get("status") as? String) == "pending"
    }

    /// Svara på en inbjudan. Vid accept läggs användaren till i teamet
    /// (reglerna tillåter det bara när en väntande inbjudan finns).
    func respondToInvite(_ invite: TeamInvite, accept: Bool, myName: String) async throws {
        guard let inviteID = invite.id else { return }
        if accept {
            try await db.collection("teams").document(invite.teamId).updateData([
                "memberUids": FieldValue.arrayUnion([invite.toUid]),
                "memberNames.\(invite.toUid)": myName
            ])
        }
        try await db.collection("teamInvites").document(inviteID)
            .updateData(["status": accept ? "accepted" : "declined"])
    }

    /// Tar bort en medlem (används både när man lämnar själv och när ägaren
    /// tar bort någon). Kommande träffar städas av onTeamMembersChanged.
    /// Ägarens borttagning av en medlem — får röra konsulentlistan.
    func removeMember(teamID: String, uid: String) async throws {
        try await db.collection("teams").document(teamID).updateData([
            "memberUids": FieldValue.arrayRemove([uid]),
            "memberNames.\(uid)": FieldValue.delete(),
            "consultantUids": FieldValue.arrayRemove([uid])
        ])
    }

    /// Medlem lämnar själv. Reglerna tillåter då BARA memberUids/memberNames —
    /// arrayRemove på consultantUids (som removeMember gör) skulle ändra/skapa
    /// det fältet och få hela uppdateringen tyst nekad. En kvarlämnad
    /// konsulent-uid är ofarlig: rollen syns bara för medlemmar.
    func leaveTeam(teamID: String, uid: String) async throws {
        try await db.collection("teams").document(teamID).updateData([
            "memberUids": FieldValue.arrayRemove([uid]),
            "memberNames.\(uid)": FieldValue.delete()
        ])
    }

    /// Sätter (eller tar bort) teamets profilbild. Endast ägaren via reglerna.
    func setTeamPhoto(teamID: String, photoData: Data?) async throws {
        try await db.collection("teams").document(teamID).updateData([
            "photoData": photoData ?? FieldValue.delete()
        ])
    }

    func deleteTeam(teamID: String) async throws {
        try await db.collection("teams").document(teamID).delete()
    }

    // MARK: - Träffar

    func createMeetup(
        title: String,
        locationName: String,
        date: Date,
        ownerUid: String,
        ownerName: String,
        team: Team?,
        invited: [(uid: String, name: String)],
        latitude: Double? = nil,
        longitude: Double? = nil,
        occurrences: Int = 1,
        intervalWeeks: Int = 1,
        maxSpots: Int? = nil
    ) async throws {
        var names = Dictionary(uniqueKeysWithValues: invited.map { ($0.uid, $0.name) })
        names[ownerUid] = ownerName

        // En kurs = flera tillfällen med samma gäng; ett vanligt tillfälle = 1.
        let count = max(1, occurrences)
        let seriesId = count > 1 ? UUID().uuidString : nil

        for index in 0..<count {
            let occurrenceDate = Calendar.current.date(
                byAdding: .day,
                value: index * intervalWeeks * 7,
                to: date
            ) ?? date
            let meetup = Meetup(
                title: title,
                locationName: locationName,
                date: occurrenceDate,
                ownerUid: ownerUid,
                ownerName: ownerName,
                teamId: team?.id,
                teamName: team?.name,
                invitedUids: invited.map(\.uid),
                invitedNames: names,
                goingUids: [ownerUid],
                declinedUids: [],
                createdAt: .now,
                latitude: latitude,
                longitude: longitude,
                seriesId: seriesId,
                seriesIndex: count > 1 ? index + 1 : nil,
                seriesCount: count > 1 ? count : nil,
                maxSpots: maxSpots
            )
            _ = try db.collection("meetups").addDocument(from: meetup)
        }
    }

    /// Ägaren bockar av närvaro för en deltagare på ett tillfälle.
    func setAttendance(meetupID: String, uid: String, attended: Bool) async throws {
        try await db.collection("meetups").document(meetupID).updateData([
            "attendedUids": attended ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid])
        ])
    }

    /// Ägaren ändrar titel, plats, tid eller kartnål i efterhand.
    func updateMeetup(
        meetupID: String,
        title: String,
        locationName: String,
        date: Date,
        latitude: Double?,
        longitude: Double?
    ) async throws {
        var data: [String: Any] = [
            "title": title,
            "locationName": locationName,
            "date": Timestamp(date: date)
        ]
        data["latitude"] = latitude.map { $0 as Any } ?? FieldValue.delete()
        data["longitude"] = longitude.map { $0 as Any } ?? FieldValue.delete()
        try await db.collection("meetups").document(meetupID).updateData(data)
    }

    /// Träffar jag är inbjuden till eller ordnar, framåt i tiden.
    func upcomingMeetups(uid: String) async -> [Meetup] {
        async let invitedSnap = try? db.collection("meetups")
            .whereField("invitedUids", arrayContains: uid)
            .getDocuments()
        async let ownedSnap = try? db.collection("meetups")
            .whereField("ownerUid", isEqualTo: uid)
            .getDocuments()

        let docs = (await invitedSnap?.documents ?? []) + (await ownedSnap?.documents ?? [])
        var seen = Set<String>()
        return docs
            .compactMap { try? $0.data(as: Meetup.self) }
            .filter { meetup in
                guard let id = meetup.id, !seen.contains(id) else { return false }
                seen.insert(id)
                return meetup.date > Calendar.current.date(byAdding: .hour, value: -6, to: .now)!
            }
            .sorted { $0.date < $1.date }
    }

    /// Svara på en träff. Namnet skrivs in i invitedNames så deltagarlistan kan
    /// visa den som svarar — särskilt viktigt för stadsträffar, där den som
    /// anmäler sig inte var inbjuden i förväg och alltså inte redan finns där.
    func setRSVP(meetupID: String, uid: String, name: String, going: Bool) async throws {
        try await db.collection("meetups").document(meetupID).updateData([
            "goingUids": going ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
            "declinedUids": going ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
            // Öppna stadsträffar: skriv in sig själv i invitedUids också —
            // upcomingMeetups/påminnelserna frågar på den listan, annars
            // syns träffen man tackat ja till aldrig under "Träffar".
            "invitedUids": FieldValue.arrayUnion([uid]),
            "invitedNames.\(uid)": name
        ])
    }

    func deleteMeetup(meetupID: String) async throws {
        try await db.collection("meetups").document(meetupID).delete()
    }
}
