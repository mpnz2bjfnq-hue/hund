//
//  UppdragHundTests.swift
//  UppdragHundTests
//
//  Created by Alex  on 2026-07-13.
//

import Testing
import Foundation
import SwiftData
@testable import UppdragHund

struct UppdragHundTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Dog.self, HealthEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    @Test func creatingDogPersistsItInContext() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)
        try context.save()

        let dogs = try context.fetch(FetchDescriptor<Dog>())
        #expect(dogs.count == 1)
        #expect(dogs.first?.name == "Bella")
    }

    @MainActor
    @Test func deletingDogRemovesItFromContext() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(dog)
        try context.save()

        context.delete(dog)
        try context.save()

        let dogs = try context.fetch(FetchDescriptor<Dog>())
        #expect(dogs.isEmpty)
    }

}

struct AgeFormatterTests {

    private let calendar = Calendar.current

    @Test func describesNewbornAsNyfödd() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let birthDate = calendar.date(byAdding: .day, value: -2, to: now)!
        #expect(AgeFormatter.describe(birthDate: birthDate, asOf: now) == "Nyfödd")
    }

    @Test func describesAgeInWeeksForYoungPuppy() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let birthDate = calendar.date(byAdding: .day, value: -21, to: now)!
        #expect(AgeFormatter.describe(birthDate: birthDate, asOf: now) == "3 veckor")
    }

    @Test func describesAgeInMonths() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let birthDate = calendar.date(byAdding: .month, value: -5, to: now)!
        #expect(AgeFormatter.describe(birthDate: birthDate, asOf: now) == "5 månader")
    }

    @Test func describesAgeInYearsAndMonths() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let birthDate = calendar.date(byAdding: DateComponents(year: -2, month: -3), to: now)!
        #expect(AgeFormatter.describe(birthDate: birthDate, asOf: now) == "2 år 3 mån")
    }

    @Test func describesWholeYearWithoutMonths() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let birthDate = calendar.date(byAdding: .year, value: -4, to: now)!
        #expect(AgeFormatter.describe(birthDate: birthDate, asOf: now) == "4 år")
    }

}

struct HealthEventTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Dog.self, HealthEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    @Test func creatingHealthEventLinksItToDog() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)

        let event = HealthEvent(type: .weighing, title: "Vägning", date: .now, weightKg: 28.4, dog: dog)
        context.insert(event)
        try context.save()

        #expect(dog.healthEvents.count == 1)
        #expect(dog.healthEvents.first?.weightKg == 28.4)
    }

    @MainActor
    @Test func deletingDogCascadesToHealthEvents() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(dog)
        let event = HealthEvent(type: .injury, title: "Hälta", date: .now, bodyLocation: .backRightLeg, dog: dog)
        context.insert(event)
        try context.save()

        context.delete(dog)
        try context.save()

        let remainingEvents = try context.fetch(FetchDescriptor<HealthEvent>())
        #expect(remainingEvents.isEmpty)
    }

    @Test func weighingsSortedByDateFiltersAndSortsCorrectly() {
        let older = HealthEvent(type: .weighing, title: "Vägning", date: Date(timeIntervalSince1970: 1000), weightKg: 20)
        let newer = HealthEvent(type: .weighing, title: "Vägning", date: Date(timeIntervalSince1970: 2000), weightKg: 22)
        let unrelated = HealthEvent(type: .note, title: "Anteckning", date: Date(timeIntervalSince1970: 1500))

        let sorted = [newer, unrelated, older].weighingsSortedByDate

        #expect(sorted.map(\.weightKg) == [20, 22])
    }

}

struct HeatCycleTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Dog.self, HeatCycle.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func ongoingCycleHasNoDuration() {
        let cycle = HeatCycle(startDate: .now)
        #expect(cycle.isOngoing)
        #expect(cycle.durationInDays == nil)
    }

    @Test func completedCycleComputesDuration() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Calendar.current.date(byAdding: .day, value: 18, to: start)!
        let cycle = HeatCycle(startDate: start, endDate: end)
        #expect(!cycle.isOngoing)
        #expect(cycle.durationInDays == 18)
    }

    @MainActor
    @Test func deletingDogCascadesToHeatCycles() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Luna", breed: "Border Collie", birthDate: .now, sex: .female)
        context.insert(dog)
        let cycle = HeatCycle(startDate: .now, dog: dog)
        context.insert(cycle)
        try context.save()

        context.delete(dog)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<HeatCycle>())
        #expect(remaining.isEmpty)
    }

    @Test func historyIgnoresOngoingCycleAndComputesIntervals() {
        let calendar = Calendar.current
        let firstStart = Date(timeIntervalSince1970: 0)
        let firstEnd = calendar.date(byAdding: .day, value: 20, to: firstStart)!
        let secondStart = calendar.date(byAdding: .day, value: 114, to: firstStart)!
        let secondEnd = calendar.date(byAdding: .day, value: 19, to: secondStart)!
        let ongoingStart = calendar.date(byAdding: .day, value: 300, to: firstStart)!

        let first = HeatCycle(startDate: firstStart, endDate: firstEnd)
        let second = HeatCycle(startDate: secondStart, endDate: secondEnd)
        let ongoing = HeatCycle(startDate: ongoingStart)

        let history = HeatCycleAnalyzer.history(from: [second, ongoing, first])

        #expect(history.count == 2)
        #expect(history.first?.cycle === second)
        #expect(history.first?.intervalSincePreviousDays == 114)
        #expect(history.last?.cycle === first)
        #expect(history.last?.intervalSincePreviousDays == nil)
    }

}

struct BreedReferenceMatcherTests {

    private let references = [
        BreedReference(breedName: "Schäfer", sizeCategory: .large, averageCycleIntervalDays: 210, averageCycleDurationDays: 20),
        BreedReference(breedName: "Malinois", sizeCategory: .medium, averageCycleIntervalDays: 195, averageCycleDurationDays: 19),
    ]

    @Test func findsExactCaseInsensitiveMatch() {
        let result = BreedReferenceMatcher.reference(forBreed: "schäfer", in: references)
        #expect(result.breedName == "Schäfer")
        #expect(result.averageCycleIntervalDays == 210)
    }

    @Test func trimsWhitespaceBeforeMatching() {
        let result = BreedReferenceMatcher.reference(forBreed: "  Malinois  ", in: references)
        #expect(result.breedName == "Malinois")
    }

    @Test func fallsBackToGenericForUnknownBreed() {
        let result = BreedReferenceMatcher.reference(forBreed: "Blandras", in: references)
        #expect(result == BreedReference.genericFallback)
    }

    @Test func fallsBackToGenericForEmptyBreed() {
        let result = BreedReferenceMatcher.reference(forBreed: "   ", in: references)
        #expect(result == BreedReference.genericFallback)
    }

    @Test func decodesBundledJSONShape() throws {
        let json = """
        [{"breedName":"Testras","sizeCategory":"medium","averageCycleIntervalDays":195,"averageCycleDurationDays":19}]
        """
        let decoded = try JSONDecoder().decode([BreedReference].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        #expect(decoded.first?.breedName == "Testras")
        #expect(decoded.first?.sizeCategory == .medium)
    }

}

struct HeatPredictorTests {

    private let calendar = Calendar.current
    private let schäfer = BreedReference(breedName: "Schäfer", sizeCategory: .large, averageCycleIntervalDays: 210, averageCycleDurationDays: 20)

    @Test func usesBreedReferenceWhenNoHistory() {
        let prediction = HeatPredictor.predict(completedCycles: [], breedReference: schäfer, calendar: calendar)
        #expect(prediction.basis == .breedReference)
        #expect(prediction.predictedIntervalDays == 210)
        #expect(prediction.predictedDurationDays == 20)
        #expect(prediction.learnedFromCycleCount == 0)
        #expect(prediction.nextExpectedStartDate == nil)
    }

    @Test func usesBreedReferenceForFirstCycleButAnchorsToItsStart() {
        let start = Date(timeIntervalSince1970: 0)
        let end = calendar.date(byAdding: .day, value: 20, to: start)!
        let cycle = HeatCycle(startDate: start, endDate: end)

        let prediction = HeatPredictor.predict(completedCycles: [cycle], breedReference: schäfer, calendar: calendar)

        #expect(prediction.basis == .breedReference)
        let expectedNextStart = calendar.date(byAdding: .day, value: 210, to: start)!
        #expect(prediction.nextExpectedStartDate == expectedNextStart)
    }

    @Test func usesOwnHistoryAverageOnceTwoCyclesExist() {
        let firstStart = Date(timeIntervalSince1970: 0)
        let firstEnd = calendar.date(byAdding: .day, value: 20, to: firstStart)!
        let secondStart = calendar.date(byAdding: .day, value: 114, to: firstStart)!
        let secondEnd = calendar.date(byAdding: .day, value: 19, to: secondStart)!

        let first = HeatCycle(startDate: firstStart, endDate: firstEnd)
        let second = HeatCycle(startDate: secondStart, endDate: secondEnd)

        let prediction = HeatPredictor.predict(completedCycles: [first, second], breedReference: schäfer, calendar: calendar)

        #expect(prediction.basis == .ownHistory)
        #expect(prediction.predictedIntervalDays == 114)
        #expect(prediction.learnedFromCycleCount == 1)
        let expectedNextStart = calendar.date(byAdding: .day, value: 114, to: secondStart)!
        #expect(prediction.nextExpectedStartDate == expectedNextStart)
    }

    @Test func historyReportsDeviationFromPredictedInterval() {
        let firstStart = Date(timeIntervalSince1970: 0)
        let firstEnd = calendar.date(byAdding: .day, value: 20, to: firstStart)!
        // Second cycle starts later than the breed-reference-predicted 210 days.
        let secondStart = calendar.date(byAdding: .day, value: 211, to: firstStart)!
        let secondEnd = calendar.date(byAdding: .day, value: 19, to: secondStart)!

        let first = HeatCycle(startDate: firstStart, endDate: firstEnd)
        let second = HeatCycle(startDate: secondStart, endDate: secondEnd)

        let history = HeatCycleAnalyzer.history(from: [first, second], breedReference: schäfer, calendar: calendar)

        #expect(history.first?.cycle === second)
        #expect(history.first?.deviationFromPredictedDays == 1)
        #expect(history.last?.deviationFromPredictedDays == nil)
    }

}

struct NotificationServiceTests {

    private let calendar = Calendar.current

    @Test func triggerDateComponentsUseNineInTheMorning() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let components = NotificationService.triggerDateComponents(for: date, calendar: calendar)

        #expect(components.hour == 9)
        #expect(components.minute == 0)
        #expect(components.year == calendar.component(.year, from: date))
        #expect(components.month == calendar.component(.month, from: date))
        #expect(components.day == calendar.component(.day, from: date))
    }

    @Test func shouldScheduleOnlyForFutureDates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let future = calendar.date(byAdding: .day, value: 5, to: now)!
        let past = calendar.date(byAdding: .day, value: -5, to: now)!

        #expect(NotificationService.shouldSchedule(predictedStartDate: future, referenceDate: now))
        #expect(!NotificationService.shouldSchedule(predictedStartDate: past, referenceDate: now))
        #expect(!NotificationService.shouldSchedule(predictedStartDate: now, referenceDate: now))
    }

    @Test func identifierIsStablePerDog() {
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        let first = NotificationService.identifier(for: dog)
        let second = NotificationService.identifier(for: dog)
        #expect(first == second)
    }

}

struct DiaryEntryTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Dog.self, DiaryEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    @Test func creatingDiaryEntryLinksItToDog() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)

        let entry = DiaryEntry(date: .now, bleedingLevel: 2, mood: .good, dog: dog)
        context.insert(entry)
        try context.save()

        #expect(dog.diaryEntries.count == 1)
        #expect(dog.diaryEntries.first?.bleedingLevel == 2)
        #expect(dog.diaryEntries.first?.mood == .good)
    }

    @MainActor
    @Test func deletingDogCascadesToDiaryEntries() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(dog)
        let entry = DiaryEntry(date: .now, dog: dog)
        context.insert(entry)
        try context.save()

        context.delete(dog)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<DiaryEntry>())
        #expect(remaining.isEmpty)
    }

    @Test func defaultLevelsAreMidRange() {
        let entry = DiaryEntry(date: .now)
        #expect(entry.appetiteLevel == 3)
        #expect(entry.energyLevel == 3)
        #expect(entry.bleedingLevel == 0)
        #expect(entry.swellingLevel == 0)
        #expect(entry.mood == .neutral)
    }

}

struct MealEntryTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Dog.self, MealEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    @Test func creatingMealEntryLinksItToDog() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)

        let entry = MealEntry(type: .snack, time: .now, name: "Monster – Kanin", note: "Blev dålig i magen", dog: dog)
        context.insert(entry)
        try context.save()

        #expect(dog.mealEntries.count == 1)
        #expect(dog.mealEntries.first?.name == "Monster – Kanin")
        #expect(dog.mealEntries.first?.type == .snack)
    }

    @MainActor
    @Test func deletingDogCascadesToMealEntries() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(dog)
        let entry = MealEntry(type: .meal, time: .now, name: "Foder", dog: dog)
        context.insert(entry)
        try context.save()

        context.delete(dog)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<MealEntry>())
        #expect(remaining.isEmpty)
    }

}

struct TrainingSessionTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Dog.self, TrainingSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @MainActor
    @Test func creatingTrainingSessionLinksItToDog() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female)
        context.insert(dog)

        let session = TrainingSession(date: .now, activity: "Inkallning", durationMinutes: 15, dog: dog)
        context.insert(session)
        try context.save()

        #expect(dog.trainingSessions.count == 1)
        #expect(dog.trainingSessions.first?.activity == "Inkallning")
        #expect(dog.trainingSessions.first?.durationMinutes == 15)
    }

    @MainActor
    @Test func deletingDogCascadesToTrainingSessions() throws {
        let context = try makeInMemoryContext()
        let dog = Dog(name: "Rex", breed: "Malinois", birthDate: .now, sex: .male)
        context.insert(dog)
        let session = TrainingSession(date: .now, activity: "Fot", dog: dog)
        context.insert(session)
        try context.save()

        context.delete(dog)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<TrainingSession>())
        #expect(remaining.isEmpty)
    }

}

struct PDFReportGeneratorTests {

    @Test func generatesNonEmptyValidPDFData() {
        let event = HealthEvent(type: .weighing, title: "Vägning", date: .now, weightKg: 24.5)
        let data = PDFReportGenerator.generateReport(
            dogName: "Bella",
            dogBreed: "Schäfer",
            healthEvents: [event],
            heatCycleEntries: [],
            includeHealth: true,
            includeHeat: false
        )

        #expect(!data.isEmpty)
        let header = data.prefix(5)
        #expect(header == Data("%PDF-".utf8))
    }

    @Test func generatesValidPDFDataWithNoEntries() {
        let data = PDFReportGenerator.generateReport(
            dogName: "Bella",
            dogBreed: "Schäfer",
            healthEvents: [],
            heatCycleEntries: [],
            includeHealth: true,
            includeHeat: true
        )

        #expect(!data.isEmpty)
        #expect(data.prefix(5) == Data("%PDF-".utf8))
    }

}
