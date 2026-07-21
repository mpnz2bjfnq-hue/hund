//
//  ModerationService.swift
//  UppdragHund
//
//  Rapportering av innehåll och blockering av användare (App Review 1.2).
//  Blockerade uids lagras i Firestore under users/{uid}/blocked/{blockedUid}
//  så listan följer med mellan enheter. Anmälningar skrivs till reports/
//  och läses endast via Firebase Console.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class ModerationService {
    static let shared = ModerationService()

    private let db = Firestore.firestore()
    /// Cache för snabb filtrering i UI:t under sessionen.
    private(set) var blockedUids: Set<String> = []

    private init() {}

    // MARK: - Blockering

    @discardableResult
    func refreshBlocked(for uid: String) async -> Set<String> {
        let snapshot = try? await db.collection("users").document(uid)
            .collection("blocked").getDocuments()
        blockedUids = Set(snapshot?.documents.map(\.documentID) ?? [])
        return blockedUids
    }

    func block(uid targetUid: String, name: String, by myUid: String) async throws {
        try await db.collection("users").document(myUid)
            .collection("blocked").document(targetUid)
            .setData(["name": name, "createdAt": FieldValue.serverTimestamp()])
        blockedUids.insert(targetUid)
    }

    func unblock(uid targetUid: String, by myUid: String) async throws {
        try await db.collection("users").document(myUid)
            .collection("blocked").document(targetUid).delete()
        blockedUids.remove(targetUid)
    }

    func blockedUsers(for uid: String) async -> [(uid: String, name: String)] {
        let snapshot = try? await db.collection("users").document(uid)
            .collection("blocked").getDocuments()
        return snapshot?.documents.map {
            ($0.documentID, ($0.get("name") as? String) ?? "Användare")
        } ?? []
    }

    // MARK: - Rapportering

    func report(
        contentType: String,      // "post" / "comment"
        contentID: String,
        contentText: String,
        authorUid: String,
        teamId: String?,
        postID: String,           // inläggets id (== contentID för post-rapporter)
        postAuthorUid: String,    // inläggets författare (för sökvägen)
        reporterUid: String
    ) async throws {
        try await db.collection("reports").addDocument(data: [
            "contentType": contentType,
            "contentID": contentID,
            "contentText": String(contentText.prefix(300)),
            "authorUid": authorUid,
            "teamId": teamId ?? "",
            "postID": postID,
            "postAuthorUid": postAuthorUid,
            "reporterUid": reporterUid,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }
}

// MARK: - Supportärenden

enum TicketKind: String, Codable, Identifiable {
    case support, feedback
    /// Ansökan om instruktörskonto — godkänns av admin i adminpanelen.
    case instructor
    var id: String { rawValue }
}

struct SupportTicket: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var subject: String
    var message: String
    var uid: String
    var name: String
    var status: String   // "open" / "resolved"
    var kind: String?    // "support" (default) / "feedback"
    var createdAt: Date

    var isOpen: Bool { status == "open" }
    var ticketKind: TicketKind { TicketKind(rawValue: kind ?? "support") ?? .support }
}

final class SupportService {
    static let shared = SupportService()

    private let db = Firestore.firestore()

    private init() {}

    func createTicket(kind: TicketKind = .support, subject: String, message: String, uid: String, name: String) async throws {
        let ticket = SupportTicket(
            subject: subject,
            message: message,
            uid: uid,
            name: name,
            status: "open",
            kind: kind.rawValue,
            createdAt: .now
        )
        _ = try db.collection("supportTickets").addDocument(from: ticket)
    }

    func myTickets(uid: String) async -> [SupportTicket] {
        let snapshot = try? await db.collection("supportTickets")
            .whereField("uid", isEqualTo: uid)
            .getDocuments()
        return (snapshot?.documents.compactMap { try? $0.data(as: SupportTicket.self) } ?? [])
            .filter { $0.ticketKind == .support }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: Admin

    func allTickets(kind: TicketKind) async -> [SupportTicket] {
        let snapshot = try? await db.collection("supportTickets").getDocuments()
        return (snapshot?.documents.compactMap { try? $0.data(as: SupportTicket.self) } ?? [])
            .filter { $0.ticketKind == kind }
            .sorted { a, b in
                if a.isOpen != b.isOpen { return a.isOpen }
                return a.createdAt > b.createdAt
            }
    }

    func resolveTicket(id: String) async throws {
        try await db.collection("supportTickets").document(id).updateData(["status": "resolved"])
    }

    func deleteTicket(id: String) async throws {
        try await db.collection("supportTickets").document(id).delete()
    }
}

// MARK: - Admin (anmälningskö)

struct ContentReport: Identifiable {
    let id: String
    let contentType: String
    let contentID: String
    let contentText: String
    let authorUid: String
    let teamId: String?
    let postID: String
    let postAuthorUid: String
    let createdAt: Date
}

final class AdminService {
    static let shared = AdminService()

    private let db = Firestore.firestore()
    private(set) var isAdmin = false

    private init() {}

    /// Är inloggat konto admin? (Kan läsa config/admins ⇔ uid finns i listan.)
    @discardableResult
    func checkIsAdmin(uid: String) async -> Bool {
        let doc = try? await db.collection("config").document("admins").getDocument()
        let uids = (doc?.get("uids") as? [String]) ?? []
        isAdmin = uids.contains(uid)
        return isAdmin
    }

    func fetchReports() async -> [ContentReport] {
        let snapshot = try? await db.collection("reports")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot?.documents.compactMap { doc in
            ContentReport(
                id: doc.documentID,
                contentType: (doc.get("contentType") as? String) ?? "post",
                contentID: (doc.get("contentID") as? String) ?? "",
                contentText: (doc.get("contentText") as? String) ?? "",
                authorUid: (doc.get("authorUid") as? String) ?? "",
                teamId: (doc.get("teamId") as? String).flatMap { $0.isEmpty ? nil : $0 },
                postID: (doc.get("postID") as? String) ?? ((doc.get("contentID") as? String) ?? ""),
                postAuthorUid: (doc.get("postAuthorUid") as? String) ?? ((doc.get("authorUid") as? String) ?? ""),
                createdAt: (doc.get("createdAt") as? Timestamp)?.dateValue() ?? .now
            )
        } ?? []
    }

    /// Raderar det anmälda innehållet (inlägg eller kommentar) som admin.
    func deleteReportedContent(_ report: ContentReport) async throws {
        // Forum och träffar bor i egna toppkollektioner — de gamla post-
        // sökvägarna nedan träffade obefintliga dokument ("lyckades" tyst).
        switch report.contentType {
        case "forumThread":
            // Svaren följer inte med dokumentraderingen — töm dem först.
            let threadRef = db.collection("forum").document(report.postID)
            let replies = try await threadRef.collection("replies").getDocuments()
            for doc in replies.documents {
                try await doc.reference.delete()
            }
            try await threadRef.delete()
            return
        case "forumReply":
            try await db.collection("forum").document(report.postID)
                .collection("replies").document(report.contentID).delete()
            return
        case "meetup":
            try await db.collection("meetups").document(report.postID).delete()
            return
        default:
            break
        }

        let postRef: DocumentReference
        if let teamId = report.teamId {
            postRef = db.collection("teams").document(teamId)
                .collection("posts").document(report.postID)
        } else {
            postRef = db.collection("users").document(report.postAuthorUid)
                .collection("posts").document(report.postID)
        }
        if report.contentType == "comment" {
            try await postRef.collection("comments").document(report.contentID).delete()
        } else {
            try await postRef.delete()
        }
    }

    func dismissReport(id: String) async throws {
        try await db.collection("reports").document(id).delete()
    }

    // MARK: - Dashboard-statistik

    struct AdminStats {
        var users = 0
        var teams = 0
        var meetups = 0
        var openReports = 0
        var openTickets = 0
        var feedback = 0
    }

    func fetchStats() async -> AdminStats {
        var stats = AdminStats()
        async let users = try? db.collection("users").count.getAggregation(source: .server)
        async let teams = try? db.collection("teams").count.getAggregation(source: .server)
        async let meetups = try? db.collection("meetups").count.getAggregation(source: .server)
        async let reports = try? db.collection("reports").count.getAggregation(source: .server)
        async let tickets = try? db.collection("supportTickets")
            .whereField("status", isEqualTo: "open")
            .whereField("kind", isEqualTo: "support")
            .count.getAggregation(source: .server)
        async let feedback = try? db.collection("supportTickets")
            .whereField("kind", isEqualTo: "feedback")
            .count.getAggregation(source: .server)
        stats.users = await users.map { Int(truncating: $0.count) } ?? 0
        stats.teams = await teams.map { Int(truncating: $0.count) } ?? 0
        stats.meetups = await meetups.map { Int(truncating: $0.count) } ?? 0
        stats.openReports = await reports.map { Int(truncating: $0.count) } ?? 0
        stats.openTickets = await tickets.map { Int(truncating: $0.count) } ?? 0
        stats.feedback = await feedback.map { Int(truncating: $0.count) } ?? 0
        return stats
    }

    // MARK: - Användarhantering

    func listUsers(limit: Int = 200) async -> [UserProfile] {
        let snapshot = try? await db.collection("users")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot?.documents.compactMap { try? $0.data(as: UserProfile.self) } ?? []
    }

    private lazy var functions = Functions.functions(region: "europe-north1")

    /// Raderar en annan användares konto + all data (server-verifierad admin).
    func deleteUser(targetUid: String) async throws {
        _ = try await functions.httpsCallable("adminDeleteUser").call(["targetUid": targetUid])
    }

    /// Beviljar eller återkallar instruktörskonto (server-side flagga).
    func setInstructor(targetUid: String, instructor: Bool) async throws {
        _ = try await functions.httpsCallable("adminSetInstructor").call([
            "targetUid": targetUid,
            "instructor": instructor,
        ] as [String: Any])
    }

    /// Skickar push till alla användare. Returnerar (tokens, levererade).
    func broadcast(title: String, body: String) async throws -> (tokens: Int, sent: Int) {
        let result = try await functions.httpsCallable("adminBroadcast").call([
            "title": title, "body": body
        ])
        let data = result.data as? [String: Any]
        return ((data?["tokens"] as? Int) ?? 0, (data?["sent"] as? Int) ?? 0)
    }
}
