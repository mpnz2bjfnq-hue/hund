//
//  SyncTombstone.swift
//  UppdragHund
//

import Foundation
import SwiftData

/// Minnesmärke över en lokalt raderad post på en delad hund, så att nästa push
/// kan radera motsvarande Firestore-dokument utan att först läsa hela fjärrlistan.
/// `module == "dog"` betyder att hela hunden raderats (entryRemoteID är då nil).
@Model
final class SyncTombstone {
    var dogRemoteID: UUID
    var module: String
    var entryRemoteID: UUID?
    var createdAt: Date

    init(dogRemoteID: UUID, module: String, entryRemoteID: UUID? = nil) {
        self.dogRemoteID = dogRemoteID
        self.module = module
        self.entryRemoteID = entryRemoteID
        self.createdAt = .now
    }
}
