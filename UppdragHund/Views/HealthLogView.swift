//
//  HealthLogView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct HealthLogView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingNewEvent = false
    @State private var isPresentingExport = false
    @State private var filterType: HealthEventType?

    private var access: DogAccess {
        DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
    }

    private var sortedEvents: [HealthEvent] {
        dog.healthEvents.sorted { $0.date > $1.date }
    }

    private var filteredEvents: [HealthEvent] {
        guard let filterType else { return sortedEvents }
        return sortedEvents.filter { $0.type == filterType }
    }

    var body: some View {
        Group {
            if !access.isModuleVisible(.health) {
                ModuleNotSharedView()
            } else {
                eventList
            }
        }
        .navigationTitle("Hälsa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if access.canLog(in: .health) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewEvent = true
                    } label: {
                        Label("Ny", systemImage: "plus")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingExport = true
                } label: {
                    Label("PDF", systemImage: "square.and.arrow.down")
                }
                .accessibilityLabel("Exportera som PDF")
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button("Alla typer") { filterType = nil }
                    Divider()
                    ForEach(HealthEventType.allCases) { type in
                        Button(type.displayName) { filterType = type }
                    }
                } label: {
                    Label("Filtrera", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $isPresentingNewEvent) {
            NewHealthEventView(dog: dog)
        }
        .sheet(isPresented: $isPresentingExport) {
            ExportPDFView(dog: dog)
        }
    }

    private var eventList: some View {
        List {
            Section {
                if filteredEvents.isEmpty {
                    ContentUnavailableView(
                        "Inga loggposter",
                        systemImage: "stethoscope",
                        description: Text(access.canLog(in: .health)
                            ? "Tryck på + för att logga något om \(dog.name)."
                            : "Inget loggat än.")
                    )
                } else {
                    ForEach(filteredEvents) { event in
                        HealthEventRow(event: event)
                            .deleteDisabled(!access.canModify(entryCreatedByUid: event.createdByUid))
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            SyncCoordinator.shared.delete(filteredEvents[index], of: dog, in: modelContext)
                        }
                    }
                }
            } header: {
                Text("Historik")
            }
        }
    }
}

private struct HealthEventRow: View {
    let event: HealthEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.headline)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LoggedByLine(name: event.createdByName)
            }
        }
    }

    private var detailText: String {
        var parts = [event.type.displayName, event.date.formatted(date: .abbreviated, time: .omitted)]
        if event.type == .injury {
            if let injuryView = event.injuryView {
                parts.append(injuryView.displayName)
            } else if let bodyLocation = event.bodyLocation {
                parts.append(bodyLocation.displayName)
            }
            if let status = event.injuryStatus {
                parts.append(status.displayName)
            }
        } else if let bodyLocation = event.bodyLocation {
            parts.append(bodyLocation.displayName)
        }
        if let weight = event.weightKg {
            parts.append(String(format: "%.1f kg", weight))
        }
        if let temp = event.temperatureCelsius {
            parts.append(String(format: "%.1f °C", temp))
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        HealthLogView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, HealthEvent.self], inMemory: true)
}
