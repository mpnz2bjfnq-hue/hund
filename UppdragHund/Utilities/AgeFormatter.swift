//
//  AgeFormatter.swift
//  UppdragHund
//

import Foundation

enum AgeFormatter {
    static func describe(birthDate: Date, asOf referenceDate: Date = .now) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: referenceDate)
        let years = max(components.year ?? 0, 0)
        let months = max(components.month ?? 0, 0)
        let days = max(components.day ?? 0, 0)

        if years >= 1 {
            guard months > 0 else {
                return years == 1 ? String(localized: "1 år") : String(localized: "\(years) år")
            }
            return String(localized: "\(years) år \(months) mån")
        }

        if months >= 1 {
            return months == 1 ? String(localized: "1 månad") : String(localized: "\(months) månader")
        }

        let weeks = days / 7
        if weeks >= 1 {
            return weeks == 1 ? String(localized: "1 vecka") : String(localized: "\(weeks) veckor")
        }

        return String(localized: "Nyfödd")
    }
}
