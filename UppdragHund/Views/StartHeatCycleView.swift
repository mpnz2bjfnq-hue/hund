//
//  StartHeatCycleView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct StartHeatCycleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let dog: Dog

    @State private var startDate = Date.now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Startdatum", selection: $startDate, in: ...Date.now, displayedComponents: .date)
            }
            .navigationTitle("Registrera nytt löp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Spara") {
                let cycle = HeatCycle(startDate: startDate, dog: dog)
                modelContext.insert(cycle)
                SyncCoordinator.shared.entryTouched(cycle, dog: dog)
                dismiss()
            }
        }
    }
}

#Preview {
    StartHeatCycleView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
        .modelContainer(for: [Dog.self, HeatCycle.self], inMemory: true)
}
