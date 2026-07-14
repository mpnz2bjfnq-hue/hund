//
//  EndHeatCycleView.swift
//  UppdragHund
//

import SwiftUI

struct EndHeatCycleView: View {
    @Environment(\.dismiss) private var dismiss

    let cycle: HeatCycle

    @State private var endDate: Date

    init(cycle: HeatCycle) {
        self.cycle = cycle
        _endDate = State(initialValue: max(cycle.startDate, .now))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Slutdatum", selection: $endDate, in: cycle.startDate...Date.now, displayedComponents: .date)
            }
            .navigationTitle("Avsluta löp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        cycle.endDate = endDate
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EndHeatCycleView(cycle: HeatCycle(startDate: .now))
}
