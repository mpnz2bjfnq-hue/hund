//
//  UserProfile.swift
//  UppdragHund
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    var handle: String
    var email: String?
    var createdAt: Date
}
