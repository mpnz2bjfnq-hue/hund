//
//  ProfilePost.swift
//  UppdragHund
//
//  En uppdatering/inlägg på en användares profil. Textbaserad i v1
//  (inga foton). Lagras i Firestore under users/{uid}/posts/{postId}.
//

import Foundation
import FirebaseFirestore

struct ProfilePost: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var authorUid: String
    var authorName: String
    var text: String
    var createdAt: Date
    // Valfri koppling till en av författarens hundar.
    var dogRemoteID: String?
    var dogName: String?
}
