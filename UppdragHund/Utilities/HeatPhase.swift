//
//  HeatPhase.swift
//  UppdragHund
//
//  Fas i ett löp utifrån dag-i-cykeln. Ungefärliga, rasgenerella gränser:
//  proöstrus (förlöp) dag 1–9, östrus (höglöp) dag 10 och framåt.
//  Metöstrus/anöstrus ligger efter det synliga löpet och visas inte här.
//

import Foundation

enum HeatPhase: Equatable {
    case proestrus   // förlöp
    case estrus      // höglöp

    /// Klinisk term.
    var displayName: String {
        switch self {
        case .proestrus: "Proöstrus"
        case .estrus: "Östrus"
        }
    }

    /// Vardaglig svensk term.
    var swedishCommon: String {
        switch self {
        case .proestrus: "Förlöp"
        case .estrus: "Höglöp"
        }
    }

    /// Fyllnadsopacitet för kalenderns löp-markering (östrus starkare).
    var fillOpacity: Double {
        switch self {
        case .proestrus: 0.35
        case .estrus: 0.7
        }
    }

    /// Dag 1 = startdagen.
    static func forDayInCycle(_ day: Int) -> HeatPhase {
        day <= 9 ? .proestrus : .estrus
    }

    /// Fasen ett visst datum har inom ett löp, eller nil om datumet ligger utanför.
    /// Ett pågående löp begränsas uppåt till idag (framtida dagar har ingen fas än).
    static func phase(on date: Date, in cycle: HeatCycle, calendar: Calendar = .current) -> HeatPhase? {
        let start = calendar.startOfDay(for: cycle.startDate)
        let end = calendar.startOfDay(for: cycle.endDate ?? .now)
        let day0 = calendar.startOfDay(for: date)
        guard day0 >= start, day0 <= end else { return nil }
        let dayIndex = calendar.dateComponents([.day], from: start, to: day0).day ?? 0
        return forDayInCycle(dayIndex + 1)
    }
}
