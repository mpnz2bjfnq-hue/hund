//
//  HeatPhase.swift
//  UppdragHund
//
//  Fas i ett löp utifrån dag-i-cykeln, samt den kunskap appen förmedlar
//  om löpet.
//
//  VIKTIGT om dagsiffrorna nedan: de är populationsgenomsnitt och duger
//  bara till att beskriva var i löpet man ungefär är. De duger INTE till
//  att avgöra när en enskild tik är fertil. Ägglossning har uppmätts från
//  dag 3 till dag 31 efter löpstart (beaglestudie refererad av WSAVA), och
//  samma tik kan variera upp till ~12 dagar mellan sina egna löp. Därför
//  markerar appen ingen "fertil dag" — den pekar på progesteronprov, som
//  är det enda som ger ett svar för den enskilda tiken.
//
//  Källor:
//  - SLU Universitetsdjursjukhuset, info till uppfödare (progesteron +
//    vaginalcytologi; "progesteron stiger olika snabbt hos olika tikar och
//    det kan också variera mellan olika löp hos samma tik")
//  - SSRK, Apportören 4/2022, Widebeck & von Celsing: LH-toppen ligger hos
//    de flesta tikar runt löpdygn 8 → ägglossning ~2 dygn senare → mogna,
//    befruktningsdugliga ägg ~2–3 dygn därefter. "Varje löp och varje tik
//    visar olika progesteronkurvor... du kan inte 'lita' på din tiks
//    värden under tidigare löp."
//  - Merck Veterinary Manual: proöstrus och östrus 3 dagar–3 veckor,
//    snitt 9 dagar vardera.
//

import Foundation

// Ren datummatte utan delat tillstånd → nonisolated, så statiska metoder
// kan anropas från och skickas som funktionsvärden i nonisolated-kontexter
// (SwiftData-accessorer, .map(forDayInCycle)) trots MainActor-standarden.
nonisolated enum HeatPhase: Equatable {
    case proestrus   // förlöp
    case estrus      // höglöp
    case metestrus   // efterlöp

    /// Synligt löp — så många dagar projiceras i kalendern.
    static let visibleCycleDays = 21

    /// Så länge ett oavslutat löp får färga kalendern. Ett löp som ligger kvar
    /// längre är i praktiken alltid ett glömt löp och inte ett pågående — då
    /// frågar appen i stället för att måla efterlöp i all oändlighet.
    /// Taket är generöst: östrus kan i sällsynta fall vara 3 veckor, och 21+
    /// dagars projektion ska rymmas utan att någon blir tillfrågad i onödan.
    static let maxOngoingDays = 30

    /// Löpdygnet då LH-toppen infaller hos de flesta tikar, och därmed dagen
    /// då progesteronprov ska tas om parning planeras (SSRK 4/2022).
    /// Snittvärde — provet tas just för att snittet inte går att lita på.
    static let progesteroneTestDay = 8

    /// Framförhållning för att hinna boka tid till provdagen. Ingen biologisk
    /// innebörd — bara en påminnelse om att ringa kliniken.
    static let bookingLeadDay = 6

    /// Klinisk term.
    var displayName: String {
        switch self {
        case .proestrus: String(localized: "Proöstrus")
        case .estrus: String(localized: "Östrus")
        case .metestrus: String(localized: "Metöstrus")
        }
    }

    /// Vardaglig term.
    var swedishCommon: String {
        switch self {
        case .proestrus: String(localized: "Förlöp")
        case .estrus: String(localized: "Höglöp")
        case .metestrus: String(localized: "Efterlöp")
        }
    }

    /// Vad som kännetecknar fasen kliniskt (vet. Ingunn Solberg Eriksson).
    var signs: String {
        switch self {
        case .proestrus:
            String(localized: "Svullen, hård vulva och blodiga flytningar. Tiken står inte för hanhund.")
        case .estrus:
            String(localized: "Mjukare, mindre svullen vulva och ljusare flytningar. Tiken viker svansen och står för hanhund.")
        case .metestrus:
            String(localized: "Svullnaden går ned, flytningarna blir mörka. Tiken står inte längre.")
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

    /// Dag 1 = startdagen. Gränserna är snitt — en enskild tik kan ligga
    /// långt utanför dem.
    static func forDayInCycle(_ day: Int) -> HeatPhase {
        switch day {
        case ...9: .proestrus
        case 10...15: .estrus
        default: .metestrus
        }
    }

    /// Dagen då provet bör tas.
    static func isTestDay(_ day: Int) -> Bool {
        day == progesteroneTestDay
    }

    /// Dagarna då det är dags att boka tid inför provet (dag 6–7).
    static func isBookingDay(_ day: Int) -> Bool {
        (bookingLeadDay..<progesteroneTestDay).contains(day)
    }

    /// Har ett oavslutat löp legat kvar så länge att det troligen är glömt?
    static func isOverdue(day: Int) -> Bool {
        day > maxOngoingDays
    }

    /// Dag i löpet räknat till `date` utan tak — för "löpet har pågått i N
    /// dagar", där även ett glömt löp ska kunna räknas.
    static func elapsedDays(in cycle: HeatCycle, until date: Date = .now, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: cycle.startDate)
        let day0 = calendar.startOfDay(for: date)
        return (calendar.dateComponents([.day], from: start, to: day0).day ?? 0) + 1
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
            // Pågående: visa hela projektionen, och fortsätt förbi dag 21 om
            // löpet ännu inte avslutats (visas som efterlöp) — men bara fram
            // till taket. Utan tak målar ett glömt löp kalendern för alltid.
            let hardEnd = calendar.date(byAdding: .day, value: maxOngoingDays - 1, to: start) ?? start
            end = min(max(projectedEnd, calendar.startOfDay(for: .now)), hardEnd)
        }
        guard day0 <= end else { return nil }
        return (calendar.dateComponents([.day], from: start, to: day0).day ?? 0) + 1
    }

    /// Fasen ett visst datum har inom ett löp, eller nil om datumet ligger utanför.
    static func phase(on date: Date, in cycle: HeatCycle, calendar: Calendar = .current) -> HeatPhase? {
        dayInCycle(on: date, in: cycle, calendar: calendar).map(forDayInCycle)
    }

    /// Är datumet den rekommenderade provdagen i något löp?
    static func isTestDay(on date: Date, in cycle: HeatCycle, calendar: Calendar = .current) -> Bool {
        guard let day = dayInCycle(on: date, in: cycle, calendar: calendar) else { return false }
        return isTestDay(day)
    }
}

// MARK: - Kunskapsinnehåll

/// Texterna appen visar under ett pågående löp. Samlade här så att de går
/// att granska mot källorna på ett ställe i stället för utspridda i vyerna.
enum HeatGuide {

    /// Ett steg i den genomsnittliga kedjan löpstart → befruktningsdugliga ägg.
    struct TimelineStep: Identifiable {
        let id = UUID()
        let day: String
        let title: String
        let detail: String
        let isTestStep: Bool
    }

    /// SSRK:s kedja (Apportören 4/2022, figur 1).
    static let timeline: [TimelineStep] = [
        TimelineStep(
            day: String(localized: "Dag 1"),
            title: String(localized: "Löpstart"),
            detail: String(localized: "Första blödningsdagen. Härifrån räknas alla dagar nedan."),
            isTestStep: false
        ),
        TimelineStep(
            day: String(localized: "Dag ~\(HeatPhase.progesteroneTestDay)"),
            title: String(localized: "LH-toppen – ta provet här"),
            detail: String(localized: "LH-toppen infaller hos de flesta tikar runt dygn 8. Det är här progesteronprovet ska tas om parning planeras — inte senare, då har toppen redan passerat."),
            isTestStep: true
        ),
        TimelineStep(
            day: String(localized: "Dag ~10"),
            title: String(localized: "Ägglossning"),
            detail: String(localized: "Sker ungefär 2 dygn efter LH-toppen."),
            isTestStep: false
        ),
        TimelineStep(
            day: String(localized: "Dag ~12–13"),
            title: String(localized: "Äggen är befruktningsdugliga"),
            detail: String(localized: "Hundens ägg är omogna vid ägglossningen och behöver 2–3 dygn på sig att mogna. Därför är ägglossningsdagen inte parningsdagen."),
            isTestStep: false
        )
    ]

    static let variationTitle = String(localized: "Dagarna ovan är genomsnitt")

    static let variationBody = String(localized: """
    De beskriver en tänkt medeltik, inte din. Ägglossning har uppmätts allt \
    från dag 3 till dag 31 efter löpstart, och samma tik kan variera med upp \
    till 12 dagar mellan sina egna löp. Att räkna dagar är därför inte en \
    tillförlitlig metod för att planera parning — det är den vanligaste \
    orsaken till att parningar misslyckas.
    """)

    static let testTitle = String(localized: "Bara progesteronprov ger svar för din tik")

    static let testBody = String(localized: """
    Ett blodprov hos veterinär visar var i cykeln din tik faktiskt är. Prov \
    tas runt dygn 8 och upprepas med cirka 48 timmars mellanrum tills \
    stigningen fångas. Vaginalcytologi används ofta som komplement. Progesteron \
    stiger olika snabbt hos olika tikar och kan variera mellan löp hos samma \
    tik — värden från ett tidigare löp går inte att lita på.
    """)

    static let breedTitle = String(localized: "Påverkar rasen?")

    static let breedBody = String(localized: """
    Inte var i löpet ägglossningen ligger. Rasen påverkar hur ofta löpen \
    kommer (från var fjärde månad till var 18:e hos vissa jätteraser) och när \
    första löpet infaller (6–18 månader, med stor rasvariation). Själva \
    tidpunkten för ägglossning inom löpet varierar individuellt, inte per ras.
    """)

    static let disclaimer = String(localized: """
    Informationen är allmän och ersätter inte veterinärbedömning. Kontakta \
    veterinär vid frågor om din tik.
    """)

    struct Source: Identifiable {
        let id = UUID()
        let title: String
        let url: URL
    }

    static let sources: [Source] = [
        Source(
            title: "SLU Universitetsdjursjukhuset – information till uppfödare",
            url: URL(string: "https://www.slu.se/universitetsdjursjukhuset/om-oss/varden-vi-erbjuder/specialistvard/reproduktion/djuragarinfo-till-uppfodare/")!
        ),
        Source(
            title: "SSRK, Apportören 4/2022 – Ny kunskap om tolkning av progesteronprov",
            url: URL(string: "https://ssrk.se/wp-content/uploads/2023/01/apportoren-4-2022-progesteronprov.pdf")!
        ),
        Source(
            title: "Merck Veterinary Manual – Breeding Management of Dogs and Cats",
            url: URL(string: "https://www.merckvetmanual.com/management-and-nutrition/management-of-reproduction-dogs-and-cats/breeding-management-of-dogs-and-cats")!
        )
    ]

    // MARK: - Notiser

    /// En push under ett pågående löp. Notiser ligger BARA på dagar som bär
    /// ett beslut. Tidigare låg en daglig räknare här — 28 pushar som
    /// berättade vad ägaren redan visste, vilket lär folk att svepa bort
    /// appens notiser. Lägg inte till en dag här utan att den motiverar att
    /// ägaren avbryter det hen håller på med.
    struct Nudge {
        let day: Int
        let title: String
        let body: String
    }

    static func nudges(dogName: String) -> [Nudge] {
        [
            Nudge(
                day: HeatPhase.bookingLeadDay,
                title: String(localized: "Dags att boka prov?"),
                body: String(localized: "Planerar du parning med \(dogName)? Progesteronprovet tas runt dygn \(HeatPhase.progesteroneTestDay) — boka tid nu.")
            ),
            Nudge(
                day: HeatPhase.progesteroneTestDay,
                title: String(localized: "Provdag"),
                body: String(localized: "\(dogName) är på dygn \(HeatPhase.progesteroneTestDay). Ett progesteronprov idag fångar LH-toppen hos de flesta tikar.")
            ),
            Nudge(
                day: HeatPhase.maxOngoingDays,
                title: String(localized: "Pågår löpet fortfarande?"),
                body: String(localized: "\(dogName)s löp har varit registrerat i \(HeatPhase.maxOngoingDays) dagar. Avsluta det i Kalender om det är över.")
            )
        ]
    }

    /// Alla dagnummer som någonsin haft en notis — inklusive den gamla dagliga
    /// räknaren (dag 1–28), så att redan schemalagda notiser i befintliga
    /// installationer städas bort vid nästa schemaläggning.
    static let notificationDayRange = 1...max(28, HeatPhase.maxOngoingDays)

    /// Kort rad som visas för dagens läge i ett pågående löp.
    static func todayHint(forDay day: Int) -> String? {
        if HeatPhase.isBookingDay(day) {
            return String(localized: "Planerar du parning? Boka progesteronprov — det tas runt dygn \(HeatPhase.progesteroneTestDay).")
        }
        if HeatPhase.isTestDay(day) {
            return String(localized: "Rekommenderad provdag. Progesteronprov idag fångar LH-toppen hos de flesta tikar.")
        }
        if day > HeatPhase.progesteroneTestDay && day <= 15 {
            return String(localized: "Provdagen (dygn \(HeatPhase.progesteroneTestDay)) har passerat. Kontakta veterinär om parning planeras — proverna kan behöva tas tätare nu.")
        }
        return nil
    }
}
