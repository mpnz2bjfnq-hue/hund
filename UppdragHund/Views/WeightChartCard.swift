//
//  WeightChartCard.swift
//  UppdragHund
//

import SwiftUI
import Charts

struct WeightChartCard: View {
    let dog: Dog
    let weighings: [HealthEvent]

    @State private var selected: (date: Date, weight: Double)?
    @State private var isPresentingNewWeighing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Viktutveckling")
                    .font(.headline)
                Spacer()
                Button {
                    isPresentingNewWeighing = true
                } label: {
                    Label("Logga vikt", systemImage: "plus")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }

            Chart {
                ForEach(weighings) { event in
                    LineMark(
                        x: .value("Datum", event.date),
                        y: .value("Vikt", event.weightKg ?? 0)
                    )
                    PointMark(
                        x: .value("Datum", event.date),
                        y: .value("Vikt", event.weightKg ?? 0)
                    )
                }

                if let selected {
                    RuleMark(x: .value("Valt datum", selected.date))
                        .foregroundStyle(.secondary.opacity(0.3))
                    PointMark(
                        x: .value("Datum", selected.date),
                        y: .value("Vikt", selected.weight)
                    )
                    .symbolSize(140)
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 180)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    select(at: value.location, proxy: proxy, geometry: geometry)
                                }
                        )
                }
            }

            if let selected {
                Text("\(selected.date.formatted(date: .abbreviated, time: .omitted)): \(String(format: "%.1f kg", selected.weight))")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            } else if weighings.count >= 2 {
                Text("Tryck på grafen för att se exakt vikt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isPresentingNewWeighing) {
            NewHealthEventView(dog: dog, initialType: .weighing)
        }
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard !weighings.isEmpty else { return }

        // Safely resolve the plot frame from the proxy
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]

        // Ensure the drag location is within the plot area; if not, clamp to bounds
        let clampedX = min(max(location.x, frame.minX), frame.maxX)

        // Convert the x position in the plot area to a domain value (Date)
        guard let date: Date = proxy.value(atX: clampedX) else { return }

        // Find the nearest weighing by date and update selection
        guard let nearest = weighings.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return }

        selected = (nearest.date, nearest.weightKg ?? 0)
    }
}

#Preview {
    WeightChartCard(
        dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female),
        weighings: []
    )
    .padding()
}

