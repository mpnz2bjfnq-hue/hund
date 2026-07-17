//
//  HeatPhaseTests.swift
//  UppdragHundTests
//
//  Låser fast dagslogiken i löpet. Dagsiffrorna är källbelagda (se HeatPhase)
//  — ändras de ska det vara ett medvetet beslut mot en källa, inte en glidning.
//

import Testing
import Foundation
@testable import UppdragHund

struct HeatPhaseTests {

    private let calendar = Calendar(identifier: .gregorian)

    /// Löp som startade `daysAgo` dagar före `referens` och fortfarande pågår.
    private func ongoingCycle(startedDaysAgo daysAgo: Int, from reference: Date) -> HeatCycle {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: reference)!
        return HeatCycle(startDate: start)
    }

    // MARK: - Faser

    @Test func phaseBoundariesFollowTheAverages() {
        #expect(HeatPhase.forDayInCycle(1) == .proestrus)
        #expect(HeatPhase.forDayInCycle(9) == .proestrus)
        #expect(HeatPhase.forDayInCycle(10) == .estrus)
        #expect(HeatPhase.forDayInCycle(15) == .estrus)
        #expect(HeatPhase.forDayInCycle(16) == .metestrus)
        #expect(HeatPhase.forDayInCycle(21) == .metestrus)
    }

    // MARK: - Provdag

    @Test func testDayIsDayEightOnly() {
        #expect(HeatPhase.isTestDay(HeatPhase.progesteroneTestDay))
        #expect(HeatPhase.progesteroneTestDay == 8)
        for day in [1, 6, 7, 9, 10, 12, 13, 14] {
            #expect(!HeatPhase.isTestDay(day), "dag \(day) ska inte vara provdag")
        }
    }

    /// Dag 6–7 är bokningsfönstret — inte dag 8 (då tas provet) och inte dag 5.
    @Test func bookingWindowIsTheTwoDaysBeforeTheTest() {
        #expect(!HeatPhase.isBookingDay(5))
        #expect(HeatPhase.isBookingDay(6))
        #expect(HeatPhase.isBookingDay(7))
        #expect(!HeatPhase.isBookingDay(8))
    }

    // MARK: - Dag i cykeln

    @Test func startDateIsDayOne() {
        let today = Date.now
        let cycle = ongoingCycle(startedDaysAgo: 0, from: today)
        #expect(HeatPhase.dayInCycle(on: today, in: cycle, calendar: calendar) == 1)
    }

    @Test func datesBeforeTheStartAreOutsideTheCycle() {
        let today = Date.now
        let cycle = ongoingCycle(startedDaysAgo: 0, from: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        #expect(HeatPhase.dayInCycle(on: yesterday, in: cycle, calendar: calendar) == nil)
    }

    /// Ett pågående löp projiceras hela det synliga löpet framåt direkt vid
    /// registrering — annars ser ägaren inte kommande faser.
    @Test func ongoingCycleProjectsForwardToTheVisibleWindow() {
        let today = Date.now
        let cycle = ongoingCycle(startedDaysAgo: 0, from: today)
        let dayTwentyOne = calendar.date(byAdding: .day, value: 20, to: today)!
        let dayTwentyTwo = calendar.date(byAdding: .day, value: 21, to: today)!

        #expect(HeatPhase.dayInCycle(on: dayTwentyOne, in: cycle, calendar: calendar) == 21)
        #expect(HeatPhase.dayInCycle(on: dayTwentyTwo, in: cycle, calendar: calendar) == nil)
    }

    @Test func completedCycleIsBoundedByItsEndDate() {
        let start = calendar.date(byAdding: .day, value: -20, to: .now)!
        let end = calendar.date(byAdding: .day, value: 9, to: start)!  // dag 10
        let cycle = HeatCycle(startDate: start, endDate: end)

        #expect(HeatPhase.dayInCycle(on: end, in: cycle, calendar: calendar) == 10)
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: end)!
        #expect(HeatPhase.dayInCycle(on: dayAfter, in: cycle, calendar: calendar) == nil)
    }

    @Test func testDayMarkerLandsOnDayEightOfTheCycle() {
        let today = Date.now
        let cycle = ongoingCycle(startedDaysAgo: 0, from: today)
        let dayEight = calendar.date(byAdding: .day, value: 7, to: today)!
        let daySeven = calendar.date(byAdding: .day, value: 6, to: today)!

        #expect(HeatPhase.isTestDay(on: dayEight, in: cycle, calendar: calendar))
        #expect(!HeatPhase.isTestDay(on: daySeven, in: cycle, calendar: calendar))
    }

    // MARK: - Vägledningstexter

    @Test func guidanceNudgesBookingBeforeTheTestDay() {
        let hint = HeatGuide.todayHint(forDay: 6)
        #expect(hint?.contains("Boka") == true)
    }

    @Test func guidanceFlagsTheTestDayItself() {
        let hint = HeatGuide.todayHint(forDay: 8)
        #expect(hint?.contains("provdag") == true || hint?.contains("Provdag") == true)
    }

    /// Efter provdagen ska appen inte tiga — men den ska peka på veterinär,
    /// inte på ett dagnummer.
    @Test func guidanceAfterTheTestDayPointsToAVet() {
        let hint = HeatGuide.todayHint(forDay: 12)
        #expect(hint?.contains("veterinär") == true)
    }

    @Test func guidanceIsSilentEarlyAndLateInTheCycle() {
        #expect(HeatGuide.todayHint(forDay: 1) == nil)
        #expect(HeatGuide.todayHint(forDay: 20) == nil)
    }

    /// Appen ska inte påstå att en viss dag är fertil — tidslinjen är
    /// beskrivande och provsteget ska vara utpekat som just provsteg.
    @Test func timelineMarksExactlyOneTestStep() {
        let testSteps = HeatGuide.timeline.filter(\.isTestStep)
        #expect(testSteps.count == 1)
        #expect(testSteps.first?.title.contains("LH-toppen") == true)
    }

    // MARK: - Glömt löp

    /// Utan tak målade ett glömt löp kalendern i all oändlighet.
    @Test func ongoingCycleStopsPaintingAtTheCap() {
        let start = calendar.date(byAdding: .day, value: -200, to: .now)!
        let cycle = HeatCycle(startDate: start)

        let lastPainted = calendar.date(byAdding: .day, value: HeatPhase.maxOngoingDays - 1, to: start)!
        let dayAfterCap = calendar.date(byAdding: .day, value: HeatPhase.maxOngoingDays, to: start)!

        #expect(HeatPhase.dayInCycle(on: lastPainted, in: cycle, calendar: calendar) == HeatPhase.maxOngoingDays)
        #expect(HeatPhase.dayInCycle(on: dayAfterCap, in: cycle, calendar: calendar) == nil)
        #expect(HeatPhase.dayInCycle(on: .now, in: cycle, calendar: calendar) == nil)
    }

    /// Ett löp som drar några dagar över taket ska fortfarande målas — taket
    /// får inte råka kapa ett verkligt långt löp.
    @Test func aLongButPlausibleHeatIsStillPainted() {
        let start = calendar.date(byAdding: .day, value: -25, to: .now)!
        let cycle = HeatCycle(startDate: start)
        #expect(HeatPhase.dayInCycle(on: .now, in: cycle, calendar: calendar) == 26)
        #expect(!HeatPhase.isOverdue(day: 26))
    }

    @Test func overdueStartsJustAfterTheCap() {
        #expect(!HeatPhase.isOverdue(day: HeatPhase.maxOngoingDays))
        #expect(HeatPhase.isOverdue(day: HeatPhase.maxOngoingDays + 1))
    }

    /// elapsedDays har inget tak — "har varit registrerat i N dagar" ska räkna
    /// vidare även när kalendern slutat färga.
    @Test func elapsedDaysKeepsCountingPastTheCap() {
        let start = calendar.date(byAdding: .day, value: -200, to: .now)!
        let cycle = HeatCycle(startDate: start)
        #expect(HeatPhase.elapsedDays(in: cycle, calendar: calendar) == 201)
    }

    // MARK: - Notiser

    /// Den gamla dagliga räknaren är borta. Notiser ligger bara på dagar som
    /// bär ett beslut — växer den här listan ska det vara ett medvetet val.
    @Test func nudgesOnlyLandOnDecisionDays() {
        let days = HeatGuide.nudges(dogName: "Bella").map(\.day).sorted()
        #expect(days == [HeatPhase.bookingLeadDay, HeatPhase.progesteroneTestDay, HeatPhase.maxOngoingDays])
    }

    @Test func nudgesNameTheDog() {
        for nudge in HeatGuide.nudges(dogName: "Bella") {
            #expect(nudge.body.contains("Bella"), "notis dag \(nudge.day) nämner inte hunden")
        }
    }

    /// Städspannet måste täcka den gamla räknarens dag 1–28, annars ligger
    /// redan schemalagda notiser kvar i befintliga installationer.
    @Test func cancellationRangeCoversTheLegacyDailyCounter() {
        #expect(HeatGuide.notificationDayRange.contains(1))
        #expect(HeatGuide.notificationDayRange.contains(28))
        for nudge in HeatGuide.nudges(dogName: "Bella") {
            #expect(HeatGuide.notificationDayRange.contains(nudge.day))
        }
    }
}
