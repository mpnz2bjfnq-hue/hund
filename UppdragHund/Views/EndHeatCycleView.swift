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
                // min() skyddar mot krasch när startdatumet ligger efter
                // enhetens klocka (synk från enhet med klockskevhet) —
                // ClosedRange trapar om lower > upper.
                DatePicker(
                    "Slutdatum",
                    selection: $endDate,
                    in: min(cycle.startDate, .now)...Date.now,
                    displayedComponents: .date
                )
            }
            .navigationTitle("Avsluta löp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Spara") {
                cycle.endDate = endDate
                SyncCoordinator.shared.entryTouched(cycle, dog: cycle.dog)
                dismiss()
            }
        }
    }
}

#Preview {
    EndHeatCycleView(cycle: HeatCycle(startDate: .now))
}
