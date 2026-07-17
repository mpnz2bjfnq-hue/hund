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
    @State private var selectedInjury: HealthEvent?

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
        .sheet(item: $selectedInjury) { injury in
            InjuryDetailView(event: injury)
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
                        if event.type == .injury {
                            Button {
                                selectedInjury = event
                            } label: {
                                HealthEventRow(event: event, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            .deleteDisabled(!access.canModify(entryCreatedByUid: event.createdByUid))
                        } else {
                            HealthEventRow(event: event)
                                .deleteDisabled(!access.canModify(entryCreatedByUid: event.createdByUid))
                        }
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
    var showsChevron: Bool = false

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
            if showsChevron {
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
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

// MARK: - Skadedetalj

/// Läsvy för en loggad skada: den utprickade kroppskartan, läk-status och
/// anteckning. Öppnas genom att trycka på en skada i loggen.
private struct InjuryDetailView: View {
    let event: HealthEvent
    @Environment(\.dismiss) private var dismiss

    private var status: HealingStatus { event.injuryStatus ?? .active }

    private var statusColor: Color {
        status == .healed ? Theme.Colors.verified : Theme.Colors.warning
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header

                    DogBodyMap(
                        view: .constant(event.injuryView ?? .side),
                        point: .constant(event.injuryPoint),
                        isEditable: false,
                        markerColor: statusColor
                    )
                    .frame(maxWidth: .infinity)
                    .cardStyle()

                    healingTrack

                    if let note = event.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anteckning")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(note)
                                .font(.callout)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                    }
                }
                .padding()
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Skada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
        .tint(Theme.Colors.brand)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(event.injuryView?.displayName ?? "Sida") · sedan \(event.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            Text(status.displayName)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15), in: Capsule())
                .foregroundStyle(statusColor)
        }
    }

    private var healingTrack: some View {
        let steps: [HealingStatus] = [.active, .healing, .healed]
        let currentIndex = steps.firstIndex(of: status) ?? 0
        return HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.element) { index, step in
                let reached = index <= currentIndex
                VStack(spacing: 5) {
                    Circle()
                        .fill(reached ? statusColor : Color.clear)
                        .overlay(Circle().strokeBorder(reached ? statusColor : Theme.Colors.textSecondary.opacity(0.4), lineWidth: 1.5))
                        .frame(width: 18, height: 18)
                    Text(step.displayName)
                        .font(.caption)
                        .foregroundStyle(index == currentIndex ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentIndex ? statusColor : Theme.Colors.textSecondary.opacity(0.3))
                        .frame(height: 2)
                        .offset(y: -9)
                }
            }
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        HealthLogView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
    }
    .modelContainer(for: [Dog.self, HealthEvent.self], inMemory: true)
}
