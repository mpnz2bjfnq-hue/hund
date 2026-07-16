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
    // Valfritt inbäddat träningspass (delat pass).
    var trainingPlan: SharedTrainingPlan?
    // Valfritt foto (komprimerad JPEG, ryms i dokumentet).
    var photoData: Data?
    // Satta när inlägget bara är synligt för ett team (lagras då under
    // teams/{teamId}/posts istället för users/{uid}/posts).
    var teamId: String?
    var teamName: String?
}
