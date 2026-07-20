//
//  NotificationsCenterView.swift
//  UppdragHund
//
//  Notis-/påminnelsecenter bakom klockan på Min profil. Visar kommande
//  händelser (inkl. bokade vet-besök + förväntat löp), låter dig boka nya
//  vet-besök, och slå på/av återkommande skötselpåminnelser med intervall.
//

import SwiftUI
import SwiftData

struct NotificationsCenterView: View {
    let dog: Dog?

    @Environment(\.modelContext) private var modelContext
    @State private var reminders = RecurringReminderStore.load()
    @State private var customReminders = CustomReminderStore.load()
    @State private var isPresentingAddVet = false
    @State private var isPresentingAddCustom = false

    var body: some View {
        List {
            if let dog {
                upcomingSection(dog)
            }
            customSection
            recurringSection
        }
        .navigationTitle("Notiser")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .sheet(isPresented: $isPresentingAddVet) {
            if let dog {
                AddVetVisitView(dog: dog)
            }
        }
        .sheet(isPresented: $isPresentingAddCustom) {
            AddCustomReminderView { reminder in
                customReminders.append(reminder)
                CustomReminderStore.save(customReminders)
                Task {
                    guard await NotificationService.requestAuthorizationIfNeeded() else { return }
                    await NotificationService.scheduleCustomReminder(reminder)
                }
            }
        }
        .task {
            guard let dog else { return }
            guard await NotificationService.requestAuthorizationIfNeeded() else { return }
            for event in dog.healthEvents where event.date > .now {
                await NotificationService.scheduleHealthEventNotification(for: event)
            }
        }
    }

    // MARK: - Kommande

    private func upcomingSection(_ dog: Dog) -> some View {
        Section {
            let items = upcomingItems(for: dog)
            if items.isEmpty {
                Text("Inget planerat framåt.")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(items) { item in
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: item.icon)
                            .foregroundStyle(item.tint)
                            .frame(width: 26)
                        Text(item.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .swipeActions(edge: .trailing) {
                        if let event = item.event,
                           DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
                               .canModify(entryCreatedByUid: event.createdByUid) {
                            Button(role: .destructive) {
                                deleteEvent(event, dog: dog)
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            if DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID).canLog(in: .health) {
                Button {
                    isPresentingAddVet = true
                } label: {
                    Label("Boka veterinärbesök", systemImage: "calendar.badge.plus")
                }
            }
            if !upcomingItems(for: dog).isEmpty {
                HStack {
                    HintBubble("Svep vänster på en händelse för att ta bort den", key: "hint.swipeDelete")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } header: {
            Text("Kommande")
        }
    }

    private struct UpcomingItem: Identifiable {
        let id = UUID()
        let date: Date
        let title: String
        let icon: String
        let tint: Color
        let event: HealthEvent?   // nil = prediktion (går inte att ta bort)
    }

    private func upcomingItems(for dog: Dog) -> [UpcomingItem] {
        var items = dog.healthEvents
            .filter { $0.date > .now }
            .map { event in
                UpcomingItem(
                    date: event.date,
                    title: event.title.isEmpty ? event.type.displayName : event.title,
                    icon: event.type.systemImage,
                    tint: Theme.Colors.brand,
                    event: event
                )
            }
        if dog.sex == .female, let next = nextHeatDate(for: dog), next > .now {
            items.append(UpcomingItem(
                date: next, title: "Förväntat löp",
                icon: "drop.fill", tint: Theme.Colors.heat, event: nil
            ))
        }
        return items.sorted { $0.date < $1.date }
    }

    private func deleteEvent(_ event: HealthEvent, dog: Dog) {
        NotificationService.cancelHealthEventNotification(for: event)
        SyncCoordinator.shared.delete(event, of: dog, in: modelContext)
    }

    private func nextHeatDate(for dog: Dog) -> Date? {
        let completed = dog.heatCycles.filter { !$0.isOngoing }
        let reference = BreedDataService.shared.reference(forBreed: dog.breed)
        return HeatPredictor.predict(completedCycles: completed, breedReference: reference)
            .nextExpectedStartDate
    }

    // MARK: - Egna påminnelser

    private var customSection: some View {
        Section {
            if customReminders.isEmpty {
                Text("Skapa en egen påminnelse – en gång eller återkommande.")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(customReminders) { reminder in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(reminder.scheduleDescription)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteCustom(reminder)
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }
            Button {
                isPresentingAddCustom = true
            } label: {
                Label("Ny påminnelse", systemImage: "plus")
            }
        } header: {
            Text("Egna påminnelser")
        }
    }

    private func deleteCustom(_ reminder: CustomReminder) {
        NotificationService.cancelCustomReminder(id: reminder.id)
        customReminders.removeAll { $0.id == reminder.id }
        CustomReminderStore.save(customReminders)
    }

    // MARK: - Återkommande påminnelser

    private var recurringSection: some View {
        Section {
            ForEach($reminders) { $reminder in
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(reminder.title, isOn: $reminder.isEnabled)
                    if reminder.isEnabled {
                        Stepper(intervalLabel(reminder.intervalWeeks), value: $reminder.intervalWeeks, in: 1...52)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        } header: {
            Text("Återkommande påminnelser")
        } footer: {
            Text("Notisen kommer med valt intervall, räknat från när du slår på den.")
        }
        .onChange(of: reminders) { _, updated in
            RecurringReminderStore.save(updated)
            applyReminders(updated)
        }
    }

    private func intervalLabel(_ weeks: Int) -> String {
        switch weeks {
        case 1: "Varje vecka"
        case 2: "Varannan vecka"
        default: "Var \(weeks):e vecka"
        }
    }

    private func applyReminders(_ list: [RecurringReminder]) {
        Task {
            let authed = await NotificationService.requestAuthorizationIfNeeded()
            for reminder in list {
                if reminder.isEnabled && authed {
                    await NotificationService.scheduleRecurringReminder(
                        id: reminder.id, body: reminder.body, intervalWeeks: reminder.intervalWeeks
                    )
                } else {
                    NotificationService.cancelRecurringReminder(id: reminder.id)
                }
            }
        }
    }
}

// MARK: - Ny egen påminnelse

struct AddCustomReminderView: View {
    var onSave: (CustomReminder) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
    @State private var repeatRule: ReminderRepeat = .never

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vad vill du bli påmind om?", text: $title)
                    DatePicker("När", selection: $date, in: Date.now...)
                    Picker("Upprepa", selection: $repeatRule) {
                        ForEach(ReminderRepeat.allCases) { rule in
                            Text(rule.displayName).tag(rule)
                        }
                    }
                } footer: {
                    Text(repeatRule == .never
                         ? "Notisen skickas en gång vid vald tidpunkt."
                         : "Notisen upprepas utifrån vald tidpunkt.")
                }
            }
            .navigationTitle("Ny påminnelse")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") {
                        onSave(CustomReminder(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            date: date,
                            repeatRule: repeatRule
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Boka veterinärbesök

struct AddVetVisitView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var note = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $title, prompt: Text("t.ex. Årskontroll"))
                    DatePicker("Datum", selection: $date, in: Date.now..., displayedComponents: .date)
                    TextField("Anteckning (valfritt)", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
            }
            .navigationTitle("Boka veterinärbesök")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }.disabled(!canSave)
                }
            }
            .saveErrorAlert($saveError)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let event = HealthEvent(
            type: .vetVisit,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            note: note.isEmpty ? nil : note,
            dog: dog
        )
        modelContext.insert(event)
        if let message = modelContext.saveOrMessage() {
            saveError = message
            return
        }
        Task { await NotificationService.scheduleHealthEventNotification(for: event) }
        dismiss()
    }
}
