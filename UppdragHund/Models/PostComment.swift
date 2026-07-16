//
//  PostComment.swift
//  UppdragHund
//
//  En kommentar på ett inlägg. Lagras i Firestore under
//  users/{authorUid}/posts/{postId}/comments/{commentId}.
//

import Foundation
import FirebaseFirestore

struct PostComment: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var authorUid: String
    var authorName: String
    var text: String
    var createdAt: Date
}
