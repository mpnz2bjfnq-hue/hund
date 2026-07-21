//
//  HeatCycle.swift
//  UppdragHund
//

import Foundation
import SwiftData

@Model
final class HeatCycle {
    var remoteID: UUID?
    // Synk/delning: nil createdByUid = skapad av hundens ägare på egna enheten.
    var createdByUid: String?
    var createdByName: String?
    var updatedAt: Date?
    var pendingUpload: Bool = false
    var startDate: Date
    var endDate: Date?
    var dog: Dog?

    init(startDate: Date, endDate: Date? = nil, dog: Dog? = nil) {
        self.remoteID = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.dog = dog
    }

    var isOngoing: Bool { endDate == nil }

    var durationInDays: Int? {
        guard let endDate else { return nil }
        // Normalisera till dygnsgränser — annars golvas antalet av klockslagen
        // (start kl 14 → slut kl 09 tappar en dag) och historiken motsäger
        // kalenderns "Dag N"-räkning som redan räknar i startOfDay.
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day
    }
}
