//
//  ExportPDFView.swift
//  UppdragHund
//

import SwiftUI

struct ExportPDFView: View {
    let dog: Dog

    @Environment(\.dismiss) private var dismiss
    @State private var startDate: Date
    @State private var endDate = Date.now
    @State private var includeHealth = true
    @State private var includeHeat = true
    @State private var sharePayload: SharePayload?
    @State private var showingExportError = false

    /// Identifiable-omslag så delnings-sheeten alltid har sin URL när den
    /// presenteras (undviker tom sheet vid optional+bool-tajming).
    private struct SharePayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    init(dog: Dog) {
        self.dog = dog
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
        _startDate = State(initialValue: oneYearAgo)
    }

    private var isValid: Bool {
        includeHealth || includeHeat
    }

    var body: some View {
        Form {
            Section("Datumintervall") {
                DatePicker("Från", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("Till", selection: $endDate, in: startDate...Date.now, displayedComponents: .date)
            }

            Section("Inkludera") {
                Toggle("Hälsologg", isOn: $includeHealth)
                Toggle("Löphistorik", isOn: $includeHeat)
            }
        }
        .navigationTitle("Exportera PDF")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Exportera") { generateAndShare() }
                    .disabled(!isValid)
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: [payload.url])
        }
        .alert("Export misslyckades", isPresented: $showingExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("PDF:en kunde inte skapas. Försök igen.")
        }
    }

    private func generateAndShare() {
        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate

        let filteredHealthEvents = dog.healthEvents
            .filter { $0.date >= rangeStart && $0.date < rangeEnd }
            .sorted { $0.date < $1.date }

        let breedReference = BreedDataService.shared.reference(forBreed: dog.breed)
        let filteredHeatEntries = HeatCycleAnalyzer.history(from: dog.heatCycles, breedReference: breedReference)
            .filter { $0.cycle.startDate >= rangeStart && $0.cycle.startDate < rangeEnd }
            .sorted { $0.cycle.startDate < $1.cycle.startDate }

        let data = PDFReportGenerator.generateReport(
            dogName: dog.name,
            dogBreed: dog.breed,
            healthEvents: includeHealth ? filteredHealthEvents : [],
            heatCycleEntries: includeHeat ? filteredHeatEntries : [],
            includeHealth: includeHealth,
            includeHeat: includeHeat
        )

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "Halsorapport-\(dog.name)-\(dateFormatter.string(from: .now)).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            sharePayload = SharePayload(url: tempURL)
        } catch {
            showingExportError = true
        }
    }
}

#Preview {
    ExportPDFView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
}
