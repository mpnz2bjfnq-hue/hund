//
//  HemView.swift
//  UppdragHund
//
//  Startflik: anpassningsbara block (hundkort, genvägar, översikt).
//

import SwiftUI
import SwiftData

struct HemView: View {
    let dog: Dog

    private let calendar = Calendar.current

    @AppStorage(HomeShortcutStore.storageKey) private var shortcutsRaw = HomeShortcutStore.defaultRaw
    @AppStorage(HomeBlockStore.storageKey) private var blocksRaw = HomeBlockStore.defaultRaw
    @AppStorage("home.todayInserted") private var todayInserted = false
    @State private var isEditingShortcuts = false
    @State private var isEditingHome = false

    @State private var tilesAppeared = false

    private var shortcuts: [HomeShortcut] { HomeShortcutStore.decode(shortcutsRaw) }
    private var blocks: [HomeBlock] { HomeBlockStore.decode(blocksRaw) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if blocks.isEmpty {
                    Button {
                        isEditingHome = true
                    } label: {
                        Text("Alla block är dolda. Tryck här för att anpassa hem.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack {
                        Spacer()
                        HintBubble("Anpassa hem med ⊞ där uppe 👆", key: "hint.editHome")
                    }
                    .padding(.bottom, -Theme.Spacing.m)

                    ForEach(blocks) { block in
                        switch block {
                        case .dog:       dogCard
                        case .today:     todaySection
                        case .shortcuts: shortcutsSection
                        case .overview:  oversiktSection
                        }
                    }
                }
            }
            .padding(Theme.Spacing.l)
            .animation(.spring(duration: 0.4), value: blocks)
        }
        .task { migrateTodayBlock() }
        .sheet(isPresented: $isEditingShortcuts) {
            EditShortcutsView()
        }
        .sheet(isPresented: $isEditingHome) {
            EditHomeView()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Hem")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HintBubble.dismiss("hint.editHome")
                    isEditingHome = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("Anpassa hem")
            }
        }
    }

    // MARK: - Aktiv-hund-kort

    private var dogCard: some View {
        NavigationLink {
            DogProfileDetailView(dog: dog)
        } label: {
            HStack(spacing: Theme.Spacing.l) {
                DogAvatar(photoData: dog.photoData, size: 68, isActive: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(dog.name)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(dog.breed) · \(dog.sex.displayName)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Född \(dog.birthDate.formatted(date: .abbreviated, time: .omitted)) · \(AgeFormatter.describe(birthDate: dog.birthDate))")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Genvägar

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Genvägar")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                HintBubble("Fler genvägar finns 👉", key: "hint.shortcuts")
                Button {
                    HintBubble.dismiss("hint.shortcuts")
                    isEditingShortcuts = true
                } label: {
                    Label("Ändra", systemImage: "slider.horizontal.3")
                        .font(Theme.Typography.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.brand)
                }
            }

            if shortcuts.isEmpty {
                Button {
                    isEditingShortcuts = true
                } label: {
                    Text("Lägg till genvägar")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .cardStyle()
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 4),
                    spacing: Theme.Spacing.l
                ) {
                    ForEach(shortcuts) { shortcut in
                        NavigationLink {
                            shortcut.destination(for: dog)
                        } label: {
                            shortcutLabel(shortcut)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardStyle()
            }
        }
    }

    private func shortcutLabel(_ shortcut: HomeShortcut) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: shortcut.icon)
                .font(.title2)
                .foregroundStyle(Theme.Colors.brand)
                .frame(height: 28)
            Text(shortcut.title)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Idag

    /// Dagens agenda: det som faktiskt behöver uppmärksamhet idag, samlat på
    /// ett ställe. Lokala, direkta signaler i det här steget (motion, löp,
    /// skada); träffar och team-uppgifter tillkommer.
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Idag")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            VStack(spacing: 0) {
                agendaLink(destination: HundtraningView(dog: dog)) {
                    agendaRow(
                        icon: "figure.walk",
                        text: motionAgendaText,
                        tint: Theme.Colors.brand,
                        attention: todaysTrainingMinutes == 0
                    )
                }

                if let heat = heatAgenda {
                    Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                    agendaLink(destination: KalenderView(dog: dog)) {
                        agendaRow(
                            icon: "drop.fill",
                            text: heat.text,
                            tint: Theme.Colors.heat,
                            attention: heat.attention
                        )
                    }
                }

                if let injury = recentInjury {
                    Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                    agendaLink(destination: HealthLogView(dog: dog)) {
                        agendaRow(
                            icon: "bandage.fill",
                            text: injury,
                            tint: Theme.Colors.warning,
                            attention: true
                        )
                    }
                }

                if allGood {
                    Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                    agendaRow(
                        icon: "checkmark.seal.fill",
                        text: "Allt ser bra ut idag 🐾",
                        tint: Theme.Colors.verified,
                        attention: false,
                        showsChevron: false
                    )
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
            .cardStyle()
        }
    }

    private func agendaLink<Destination: View, Label: View>(
        destination: Destination,
        @ViewBuilder label: () -> Label
    ) -> some View {
        NavigationLink { destination } label: { label() }
            .buttonStyle(.plain)
    }

    private func agendaRow(
        icon: String,
        text: String,
        tint: Color,
        attention: Bool,
        showsChevron: Bool = true
    ) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(text)
                .font(Theme.Typography.body.weight(attention ? .medium : .regular))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Spacing.s)
            if attention {
                Circle().fill(tint).frame(width: 7, height: 7)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, Theme.Spacing.s)
    }

    // MARK: Idag – data

    private var todaysTrainingMinutes: Int {
        dog.trainingSessions
            .filter { calendar.isDateInToday($0.date) }
            .compactMap(\.durationMinutes)
            .reduce(0, +)
    }

    private var motionAgendaText: String {
        todaysTrainingMinutes > 0
            ? "\(todaysTrainingMinutes) min motion loggad idag"
            : "Ingen promenad loggad än — dags för en runda med \(dog.name)?"
    }

    /// Löp-signal idag: fas + ev. progesteron-nudge. nil om ingen tik/löp.
    private var heatAgenda: (text: String, attention: Bool)? {
        guard dog.sex == .female,
              let ongoing = dog.heatCycles.first(where: { $0.isOngoing }) else { return nil }
        let day = HeatPhase.elapsedDays(in: ongoing, calendar: calendar)
        if let hint = HeatGuide.todayHint(forDay: day) {
            return (hint, true)
        }
        guard !HeatPhase.isOverdue(day: day) else {
            return ("Löp pågår – dag \(day). Avsluta det i Kalender om det är över.", true)
        }
        return ("Löp pågår – dag \(day) · \(HeatPhase.forDayInCycle(day).swedishCommon)", false)
    }

    /// Skada loggad de senaste 14 dagarna, annars nil.
    private var recentInjury: String? {
        let cutoff = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now
        return dog.healthEvents
            .filter { $0.type == .injury && $0.date >= cutoff }
            .sorted { $0.date > $1.date }
            .first
            .map { "Skada: \($0.title)" }
    }

    private var allGood: Bool {
        todaysTrainingMinutes > 0 && heatAgenda?.attention != true && recentInjury == nil
    }

    /// Lägger in Idag-blocket en gång för användare som sparat sin blocklista
    /// innan blocket fanns. Respekterar valet därefter — döljer man det stannar
    /// det dolt.
    private func migrateTodayBlock() {
        guard !todayInserted else { return }
        todayInserted = true
        var current = HomeBlockStore.decode(blocksRaw)
        guard !current.contains(.today) else { return }
        if let dogIndex = current.firstIndex(of: .dog) {
            current.insert(.today, at: current.index(after: dogIndex))
        } else {
            current.insert(.today, at: 0)
        }
        blocksRaw = HomeBlockStore.encode(current)
    }

    // MARK: - Översikt

    private var oversiktSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Översikt")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("Idag, \(Date.now.formatted(.dateTime.day().month(.wide)))")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.m
            ) {
                weightTile.tileAppear(0, shown: tilesAppeared)
                motionTile.tileAppear(1, shown: tilesAppeared)
                healthTile.tileAppear(2, shown: tilesAppeared)
                if dog.tracksHeat {
                    heatTile.tileAppear(3, shown: tilesAppeared)
                }
            }
            .onAppear { tilesAppeared = true }
        }
    }

    private var weightTile: some View {
        let weighings = dog.healthEvents.weighingsSortedByDate
        let latest = weighings.last?.weightKg
        let previous = weighings.dropLast().last?.weightKg
        var delta: String? = nil
        var deltaPositive = true
        if let latest, let previous {
            let diff = latest - previous
            if abs(diff) >= 0.05 {
                delta = String(format: "%@ %@%.1f kg", diff > 0 ? "↑" : "↓", diff > 0 ? "+" : "−", abs(diff))
                deltaPositive = diff > 0
            }
        }
        return StatTile(
            icon: "scalemass.fill", category: "Vikt",
            value: latest.map { String(format: "%.1f kg", $0) } ?? "Logga vikt",
            delta: delta, deltaPositive: deltaPositive,
            subtitle: latest == nil ? "Väg in \(dog.name) under Hälsa" : nil,
            tint: Theme.Colors.brand
        )
    }

    private var motionTile: some View {
        let todaysMinutes = dog.trainingSessions
            .filter { calendar.isDateInToday($0.date) }
            .compactMap(\.durationMinutes)
            .reduce(0, +)
        return StatTile(
            icon: "figure.walk", category: "Motion",
            value: todaysMinutes > 0 ? "\(todaysMinutes) min" : "0 min",
            subtitle: todaysMinutes > 0 ? nil : "Dags för en promenad? 🐾",
            tint: Theme.Colors.brand
        )
    }

    private var healthTile: some View {
        let injuries = dog.healthEvents
            .filter { $0.type == .injury }
            .sorted { $0.date > $1.date }
        let value = injuries.first?.title ?? "Allt bra"
        return StatTile(
            icon: "heart.text.square.fill", category: "Hälsa", value: value,
            tint: injuries.isEmpty ? Theme.Colors.brand : Theme.Colors.warning
        )
    }

    private var heatTile: some View {
        let data = heatTileData
        return StatTile(
            icon: "drop.fill", category: "Löp", value: data.value,
            subtitle: data.subtitle, tint: Theme.Colors.heat,
            pulse: dog.heatCycles.contains { $0.isOngoing }
        )
    }

    private var heatTileData: (value: String, subtitle: String?) {
        guard dog.sex == .female else { return ("–", nil) }
        if let ongoing = dog.heatCycles.first(where: { $0.isOngoing }) {
            let day = HeatPhase.elapsedDays(in: ongoing, calendar: calendar)
            // Förbi taket är löpet nästan alltid glömt — påstå ingen fas, be om
            // att det avslutas i stället.
            guard !HeatPhase.isOverdue(day: day) else {
                return ("Dag \(day)", "Avsluta löpet?")
            }
            return ("Dag \(day)", HeatPhase.forDayInCycle(day).swedishCommon)
        }
        if let next = nextHeatDate, next > .now {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: .now),
                to: calendar.startOfDay(for: next)
            ).day ?? 0
            return ("\(days) dagar", "till nästa löp")
        }
        return ("Ingen prognos än", "Registrera löp i Kalender")
    }

    // MARK: - Löp-prediktion (samma källa som Kalender)

    private var nextHeatDate: Date? {
        let completed = dog.heatCycles.filter { !$0.isOngoing }
        let reference = BreedDataService.shared.reference(forBreed: dog.breed)
        return HeatPredictor.predict(completedCycles: completed, breedReference: reference)
            .nextExpectedStartDate
    }
}

// MARK: - Stat-kort

private struct StatTile: View {
    let icon: String
    let category: String
    let value: String
    var delta: String? = nil
    var deltaPositive: Bool = true
    var subtitle: String? = nil
    let tint: Color
    var pulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .symbolEffect(.pulse, isActive: pulse)
                Text(category)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text(value)
                .font(Theme.Typography.metric)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: value)
            if let delta {
                Text(delta)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(deltaPositive ? Theme.Colors.brand : Theme.Colors.heat)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Intågs-animation för statistikrutorna

private struct TileAppearModifier: ViewModifier {
    let index: Int
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .scaleEffect(shown ? 1 : 0.96)
            .animation(.spring(duration: 0.5, bounce: 0.25).delay(Double(index) * 0.08), value: shown)
    }
}

private extension View {
    func tileAppear(_ index: Int, shown: Bool) -> some View {
        modifier(TileAppearModifier(index: index, shown: shown))
    }
}

#Preview {
    NavigationStack {
        HemView(dog: Dog(name: "Sixten", breed: "Malinois", birthDate: .now, sex: .male))
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
