//
//  DayDetailView.swift
//  UppdragHund
//

import SwiftUI

struct DayDetailView: View {
    let dog: Dog
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var diaryEntryPendingDetail: DiaryEntry?

    private let calendar = Calendar.current

    private var cycleOnThisDay: HeatCycle? {
        let day = calendar.startOfDay(for: date)
        return dog.heatCycles.first { cycle in
            let start = calendar.startOfDay(for: cycle.startDate)
            let end = calendar.startOfDay(for: cycle.endDate ?? .now)
            return day >= start && day <= end
        }
    }

    private var diaryEntry: DiaryEntry? {
        dog.diaryEntries.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var healthEventsThisDay: [HealthEvent] {
        dog.healthEvents.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var hasNothing: Bool {
        cycleOnThisDay == nil && diaryEntry == nil && healthEventsThisDay.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if let cycleOnThisDay {
                    Section("Löp") {
                        Label(cycleDescription(for: cycleOnThisDay), systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if let diaryEntry {
                    Section("Dagbok") {
                        Button {
                            diaryEntryPendingDetail = diaryEntry
                        } label: {
                            DiaryDaySummary(entry: diaryEntry)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !healthEventsThisDay.isEmpty {
                    Section("Hälsologg") {
                        ForEach(healthEventsThisDay) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.headline)
                                Text(event.type.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if hasNothing {
                    ContentUnavailableView(
                        "Inget loggat",
                        systemImage: "calendar",
                        description: Text("Inget registrerat för \(date.formatted(date: .abbreviated, time: .omitted)).")
                    )
                }
            }
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
            .sheet(item: $diaryEntryPendingDetail) { entry in
                DiaryEntryDetailView(entry: entry)
            }
        }
    }

    private func cycleDescription(for cycle: HeatCycle) -> String {
        if cycle.isOngoing {
            "Löp pågår (start \(cycle.startDate.formatted(date: .abbreviated, time: .omitted)))"
        } else {
            "Löp: \(cycle.startDate.formatted(date: .abbreviated, time: .omitted)) – \(cycle.endDate!.formatted(date: .abbreviated, time: .omitted))"
        }
    }
}

private struct DiaryDaySummary: View {
    let entry: DiaryEntry

    var body: some View {
        HStack {
            Text(entry.mood.emoji)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Blödning \(entry.bleedingLevel)/5 · Svullnad \(entry.swellingLevel)/5")
                Text("Aptit \(entry.appetiteLevel)/5 · Energi \(entry.energyLevel)/5")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            if entry.photoData != nil {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    DayDetailView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female), date: .now)
}
