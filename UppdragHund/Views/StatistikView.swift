//
//  StatistikView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData
import Charts

struct StatistikView: View {
    let dog: Dog

    @Environment(\.dismiss) private var dismiss

    private var completedCycles: [HeatCycle] {
        dog.heatCycles.filter { !$0.isOngoing }.sorted { $0.startDate < $1.startDate }
    }

    private var historyEntries: [HeatCycleAnalyzer.HistoryEntry] {
        let breedReference = BreedDataService.shared.reference(forBreed: dog.breed)
        return HeatCycleAnalyzer.history(from: dog.heatCycles, breedReference: breedReference)
    }

    private var intervals: [Int] {
        historyEntries.compactMap(\.intervalSincePreviousDays)
    }

    private var durations: [Int] {
        completedCycles.compactMap(\.durationInDays)
    }

    private var averageInterval: Int {
        guard !intervals.isEmpty else { return 0 }
        return intervals.reduce(0, +) / intervals.count
    }

    private var averageDuration: Int {
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / durations.count
    }

    private var weighings: [HealthEvent] {
        dog.healthEvents.weighingsSortedByDate
    }

    private var hasHeatCycleData: Bool {
        !completedCycles.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if hasHeatCycleData {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statTile(value: "\(completedCycles.count)", label: "Löpningar")
                        statTile(value: intervals.isEmpty ? "–" : "\(averageInterval)", label: "Snittintervall (d)")
                        statTile(value: durations.isEmpty ? "–" : "\(averageDuration)", label: "Snittlängd (d)")
                        statTile(value: dog.breed, label: "Ras")
                    }
                }

                if intervals.count >= 1 {
                    chartSection(title: "Löpintervall (dagar)") {
                        Chart {
                            ForEach(historyEntries.filter { $0.intervalSincePreviousDays != nil }, id: \.cycle.persistentModelID) { entry in
                                BarMark(
                                    x: .value("Datum", entry.cycle.startDate, unit: .month),
                                    y: .value("Dagar", entry.intervalSincePreviousDays ?? 0)
                                )
                            }
                        }
                    }
                }

                if !completedCycles.isEmpty {
                    chartSection(title: "Löplängd (dagar)") {
                        Chart(completedCycles) { cycle in
                            BarMark(
                                x: .value("Datum", cycle.startDate, unit: .month),
                                y: .value("Dagar", cycle.durationInDays ?? 0)
                            )
                        }
                    }
                }

                WeightChartCard(dog: dog, weighings: weighings)

                if !hasHeatCycleData {
                    Text("Logga löp för \(dog.name) för att se löpstatistik här.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Statistik")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func chartSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
                .frame(height: 180)
        }
    }
}

#Preview {
    NavigationStack {
        StatistikView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, HeatCycle.self, HealthEvent.self], inMemory: true)
}
