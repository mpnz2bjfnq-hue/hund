//
//  FriendRequest.swift
//  UppdragHund
//

import Foundation
import FirebaseFirestore

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct FriendRequest: Codable, Identifiable {
    @DocumentID var id: String?
    var fromUid: String
    var fromDisplayName: String
    var fromHandle: String
    var toUid: String
    var status: FriendRequestStatus
    var createdAt: Date
}
