//
//  WalkActivityAttributes.swift
//  Canine360
//
//  Live Activity-kontraktet för en pågående promenad: appen startar och
//  uppdaterar, widget-targetet ritar låsskärmen och Dynamic Island.
//  Kompileras i BÅDA targets.
//

import Foundation
import ActivityKit

struct WalkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var distanceMeters: Double
        /// Ackumulerade sekunder vid senaste uppdateringen (visas när pausad).
        var elapsedSeconds: Int
        var isPaused: Bool
        /// Referenspunkt för självtickande timer: (nu − förfluten tid).
        /// Systemet räknar upp klockan utan att appen behöver pusha varje sekund.
        var timerStart: Date
    }

    var dogName: String
}
