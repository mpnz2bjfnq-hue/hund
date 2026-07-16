//
//  ForumThread.swift
//  UppdragHund
//
//  Forumdiskussioner — öppna för alla inloggade användare. Lagras i
//  Firestore under forum/ med svaren i forum/{threadId}/replies.
//

import Foundation
import FirebaseFirestore

struct ForumThread: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var title: String
    var text: String
    var authorUid: String
    var authorName: String
    var createdAt: Date
    /// Denormaliserat antal svar + senaste aktivitet, för listvyn.
    var replyCount: Int
    var lastActivityAt: Date
}

struct ForumReply: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var text: String
    var authorUid: String
    var authorName: String
    var createdAt: Date
}
