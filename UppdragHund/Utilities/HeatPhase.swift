//
//  HeatPhase.swift
//  UppdragHund
//
//  Fas i ett löp utifrån dag-i-cykeln. Ungefärliga, rasgenerella gränser:
//  proöstrus (förlöp) dag 1–9, östrus (höglöp) dag 10–15, metöstrus
//  (efterlöp) dag 16–21. Mest fertila fönstret ligger typiskt dag 11–14
//  (ägglossning kring dag 11–13). Allt är riktvärden — individer varierar.
//

import Foundation

enum HeatPhase: Equatable {
    case proestrus   // förlöp
    case estrus      // höglöp
    case metestrus   // efterlöp

    /// Mest fertila dagarna i cykeln (riktvärde, dag 1 = startdagen).
    static let fertileDays = 11...14

    /// Synligt löp — så många dagar projiceras i kalendern.
    static let visibleCycleDays = 21

    /// Klinisk term.
    var displayName: String {
        switch self {
        case .proestrus: "Proöstrus"
        case .estrus: "Östrus"
        case .metestrus: "Metöstrus"
        }
    }

    /// Vardaglig svensk term.
    var swedishCommon: String {
        switch self {
        case .proestrus: "Förlöp"
        case .estrus: "Höglöp"
        case .metestrus: "Efterlöp"
        }
    }

    /// Kalenderfärg — tydligt åtskilda: ljus → stark → avtonande.
    var fillOpacity: Double {
        switch self {
        case .proestrus: 0.30
        case .estrus: 0.85
        case .metestrus: 0.15
        }
    }

    /// Efterlöp får dessutom en tunn ring så den inte förväxlas med förlöp.
    var showsRing: Bool { self == .metestrus }

    /// Dag 1 = startdagen.
    static func forDayInCycle(_ day: Int) -> HeatPhase {
        switch day {
        case ...9: .proestrus
        case 10...15: .estrus
        default: .metestrus
        }
    }

    /// Är dagen i det mest fertila fönstret?
    static func isFertileDay(_ day: Int) -> Bool {
        fertileDays.contains(day)
    }

    /// Dagnummer (1 = start) för ett datum inom cykeln, eller nil utanför.
    /// Ett pågående löp projiceras hela det synliga löpet (21 dagar) framåt
    /// direkt vid registrering — så ägaren ser kommande faser i kalendern.
    /// Ett avslutat löp begränsas av sitt slutdatum.
    static func dayInCycle(on date: Date, in cycle: HeatCycle, calendar: Calendar = .current) -> Int? {
        let start = calendar.startOfDay(for: cycle.startDate)
        let day0 = calendar.startOfDay(for: date)
        guard day0 >= start else { return nil }

        let projectedEnd = calendar.date(byAdding: .day, value: visibleCycleDays - 1, to: start) ?? start
        let end: Date
        if let endDate = cycle.endDate {
            end = calendar.startOfDay(for: endDate)
        } else {
            // Pågående: visa hela projektionen, och fortsätt förbi dag 21
            // om löpet ännu inte avslutats (visas som efterlöp).
            end = max(projectedEnd, calendar.startOfDay(for: .now))
        }
        guard day0 <= end else { return nil }
        return (calendar.dateComponents([.day], from: start, to: day0).day ?? 0) + 1
    }

    /// Fasen ett visst datum har inom ett löp, eller nil om datumet ligger utanför.
    static func phase(on date: Date, in cycle: HeatCycle, calendar: Calendar = .current) -> HeatPhase? {
        dayInCycle(on: date, in: cycle, calendar: calendar).map(forDayInCycle)
    }

    /// Är datumet i cykelns mest fertila fönster?
    static func isFertile(on date: Date, in cycle: HeatCycle, calendar: Calendar = .current) -> Bool {
        guard let day = dayInCycle(on: date, in: cycle, calendar: calendar) else { return false }
        return isFertileDay(day)
    }
}
