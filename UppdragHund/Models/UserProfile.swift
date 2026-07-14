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
    /// Publik summering av användarens hundar, för visning på profilen
    /// (även för vänner). Underhålls av ProfilePublisher.
    var dogSummaries: [DogSummary]?
}

struct DogSummary: Codable, Equatable, Identifiable {
    var remoteID: String
    var name: String
    var breed: String
    var birthDate: Date
    var sex: String

    var id: String { remoteID }
}
