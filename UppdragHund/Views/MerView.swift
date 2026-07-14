//
//  MerView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct MerItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
}

struct MerSheetView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @State private var selectedItem: MerItem?

    private let items: [MerItem] = [
        MerItem(title: "Promenader", systemImage: "figure.walk"),
        MerItem(title: "Foder", systemImage: "fork.knife"),
        MerItem(title: "Mål", systemImage: "target"),
        MerItem(title: "Min kull", systemImage: "person.3.fill"),
        MerItem(title: "Träning", systemImage: "dumbbell.fill"),
        MerItem(title: "Avel", systemImage: "heart.circle.fill"),
        MerItem(title: "Statistik", systemImage: "chart.bar.fill"),
        MerItem(title: "Hälsa", systemImage: "stethoscope"),
        MerItem(title: "Om oss", systemImage: "info.circle"),
    ]

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            Label(item.title, systemImage: item.systemImage)
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Mer")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                destination(for: item)
            }
        }
    }

    @ViewBuilder
    private func destination(for item: MerItem) -> some View {
        if item.title == "Hälsa", let dog = activeDogStore.activeDog {
            HealthLogView(dog: dog)
        } else if item.title == "Statistik", let dog = activeDogStore.activeDog {
            StatistikView(dog: dog)
        } else if item.title == "Foder", let dog = activeDogStore.activeDog {
            FoderdagbokView(dog: dog)
        } else if item.title == "Träning", let dog = activeDogStore.activeDog {
            HundtraningView(dog: dog)
        } else if item.title == "Om oss" {
            OmOssView()
        } else {
            PlaceholderComingSoonView(title: item.title, systemImage: item.systemImage)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Stäng") { selectedItem = nil }
                    }
                }
        }
    }
}

#Preview {
    Text("Bakgrund")
        .sheet(isPresented: .constant(true)) {
            MerSheetView()
                .environment(ActiveDogStore())
        }
        .modelContainer(for: [Dog.self, HealthEvent.self], inMemory: true)
}
