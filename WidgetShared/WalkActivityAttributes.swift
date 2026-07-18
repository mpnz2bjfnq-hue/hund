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
        /// Genomsnittstempo i sekunder per km; nil tills sträckan är meningsfull.
        var paceSecondsPerKm: Int?
    }

    var dogName: String
}

/// Gemensam formattering för promenadsiffror — används av både appens
/// promenadskärm och Live Activityn så att de alltid visar samma sak.
enum WalkFormatting {
    static func distance(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.2f", meters / 1000)
            : "\(Int(meters))"
    }

    static func distanceUnit(_ meters: Double) -> String {
        meters >= 1000 ? "km" : "m"
    }

    static func distanceWithUnit(_ meters: Double) -> String {
        "\(distance(meters)) \(distanceUnit(meters))"
    }

    static func elapsed(_ seconds: Int) -> String {
        seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// "9:32" (min:sek per km). nil under 50 m — tempo på gissningar är brus.
    static func pace(secondsPerKm: Int?) -> String {
        guard let secondsPerKm, secondsPerKm < 60 * 60 else { return "–:––" }
        return String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }

    static func paceSecondsPerKm(meters: Double, elapsedSeconds: Int) -> Int? {
        guard meters >= 50, elapsedSeconds > 0 else { return nil }
        return Int(Double(elapsedSeconds) / (meters / 1000))
    }
}
