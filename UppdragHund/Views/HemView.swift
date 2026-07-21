//
//  HemView.swift
//  UppdragHund
//
//  Startflik: anpassningsbara block (hundkort, genvägar, översikt).
//

import SwiftUI
import SwiftData
import UIKit

struct HemView: View {
    let dog: Dog

    private let calendar = Calendar.current

    @AppStorage(HomeShortcutStore.storageKey) private var shortcutsRaw = HomeShortcutStore.defaultRaw
    @AppStorage(HomeBlockStore.storageKey) private var blocksRaw = HomeBlockStore.defaultRaw
    @AppStorage("home.todayInserted") private var todayInserted = false
    @State private var authService = AuthService.shared
    /// Skalar med textstorleken så genvägsikonen inte krymper ihop mot etiketten.
    @ScaledMetric(relativeTo: .title2) private var shortcutIconHeight: CGFloat = 28
    @State private var isEditingShortcuts = false
    @State private var isEditingHome = false

    @State private var tilesAppeared = false

    // Idag-blockets async-delar (träffar och team-uppgifter).
    @State private var todayMeetups: [Meetup] = []
    @State private var nextMeetup: Meetup?
    @State private var dueTasksByTeam: [DueTasks] = []

    private struct DueTasks: Identifiable {
        let team: Team
        let count: Int
        var id: String { team.id ?? team.name }
    }

    private var shortcuts: [HomeShortcut] { HomeShortcutStore.decode(shortcutsRaw) }
    private var blocks: [HomeBlock] { HomeBlockStore.decode(blocksRaw) }

    var body: some View {
        ScrollView {
            // Mer luft mellan sektionerna — lugnare, mer premium rytm.
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
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
        .task { await loadTodayActivity() }
        .sheet(isPresented: $isEditingShortcuts) {
            EditShortcutsView()
        }
        .sheet(isPresented: $isEditingHome) {
            EditHomeView()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.screenSurface)
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

    @Namespace private var heroNamespace

    private var dogCard: some View {
        NavigationLink {
            DogProfileDetailView(dog: dog)
                .heroZoomDestination(id: "dogHero", in: heroNamespace)
        } label: {
            heroCard
                .heroZoomSource(id: "dogHero", in: heroNamespace)
        }
        .buttonStyle(CardPressStyle())
    }

    /// Hero-kort: hundens foto som bakgrund med gradient och stort namn.
    /// Utan foto: samma layout mot en mjuk brandtonad platta.
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            if let data = dog.photoData, let image = UIImage(data: data) {
                Color.clear
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    )
            } else {
                LinearGradient(
                    colors: [Theme.Colors.brand.opacity(0.35), Theme.Colors.cardBackground],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Theme.Colors.brand.opacity(0.25))
                        .padding(Theme.Spacing.xl)
                }
            }

            // Gradienten gör namnet läsbart mot vilket foto som helst —
            // börjar mjukt vid mitten och blir djupt mörk längst ned.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.35), location: 0.68),
                    .init(color: .black.opacity(0.92), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(dog.name)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(dog.breed) · \(dog.sex.displayName)")
                    .font(Theme.Typography.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                Text("Född \(dog.birthDate.formatted(date: .abbreviated, time: .omitted)) · \(AgeFormatter.describe(birthDate: dog.birthDate))")
                    .font(Theme.Typography.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(Theme.Spacing.l)
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
        .adaptiveShadow(dark: 0.35, radius: 14, y: 6)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(10)
                .background(.black.opacity(0.25), in: Circle())
                .padding(Theme.Spacing.m)
        }
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
                        .buttonStyle(CardPressStyle())
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
                .frame(minHeight: shortcutIconHeight)
            Text(shortcut.title)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Idag

    /// Dagens agenda som en roterande kortkarusell: byter mellan agenda-korten
    /// (motion, löp, träff, uppgifter) och ambient-kort (hälsning, tips,
    /// milstolpe) så Hem känns levande även en lugn dag.
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

            TodayCarousel(cards: todayCards)
        }
    }

    /// Korten som karusellen roterar mellan. Ordning: hälsning → det som kräver
    /// åtgärd → lugna/ambient kort.
    private var todayCards: [TodayCard] {
        var cards: [TodayCard] = [
            TodayCard(
                icon: greeting.icon, text: greeting.text,
                tint: Theme.Colors.brand, attention: false, destination: nil
            ),
            TodayCard(
                icon: "figure.walk", text: motionAgendaText,
                tint: Theme.Colors.brand, attention: todaysTrainingMinutes == 0,
                destination: AnyView(HundtraningView(dog: dog))
            ),
        ]

        if let heat = heatAgenda {
            cards.append(TodayCard(
                icon: "drop.fill", text: heat.text,
                tint: Theme.Colors.heat, attention: heat.attention,
                destination: AnyView(KalenderView(dog: dog))
            ))
        }
        if let injury = recentInjury {
            cards.append(TodayCard(
                icon: "bandage.fill", text: injury,
                tint: Theme.Colors.warning, attention: true,
                destination: AnyView(HealthLogView(dog: dog))
            ))
        }
        for meetup in todayMeetups {
            cards.append(TodayCard(
                icon: "calendar",
                text: String(localized: "Träff idag: \(meetup.title) kl \(meetup.date.formatted(date: .omitted, time: .shortened))"),
                tint: Theme.Colors.brand, attention: true,
                destination: AnyView(MeetupsListView())
            ))
        }
        if todayMeetups.isEmpty, let next = nextMeetup {
            cards.append(TodayCard(
                icon: "calendar",
                text: String(localized: "Nästa träff: \(next.title), \(next.date.formatted(.dateTime.weekday(.abbreviated).day().month()))"),
                tint: Theme.Colors.brand, attention: false,
                destination: AnyView(MeetupsListView())
            ))
        }
        for due in dueTasksByTeam {
            cards.append(TodayCard(
                icon: "checklist",
                text: due.count == 1
                    ? String(localized: "\(due.team.name): 1 uppgift att bocka av")
                    : String(localized: "\(due.team.name): \(due.count) uppgifter att bocka av"),
                tint: Theme.Colors.brand, attention: true,
                destination: AnyView(TeamPageView(team: due.team, startOnTasks: true))
            ))
        }

        if allGood {
            cards.append(TodayCard(
                icon: "checkmark.seal.fill", text: String(localized: "Allt ser bra ut idag 🐾"),
                tint: Theme.Colors.verified, attention: false, destination: nil
            ))
        }
        if let milestone = birthdayMilestone {
            cards.append(TodayCard(
                icon: "gift.fill", text: milestone,
                tint: Theme.Colors.verified, attention: false, destination: nil
            ))
        }
        cards.append(TodayCard(
            icon: "lightbulb.fill", text: dailyTip,
            tint: Theme.Colors.verified, attention: false, destination: nil
        ))
        return cards
    }

    // MARK: Idag – ambient

    private var greeting: (icon: String, text: String) {
        let hour = calendar.component(.hour, from: .now)
        switch hour {
        case 5..<10:  return ("sunrise.fill", String(localized: "God morgon! Redo för dagen med \(dog.name)?"))
        case 10..<12: return ("sun.max.fill", String(localized: "God förmiddag med \(dog.name) 🐾"))
        case 12..<17: return ("sun.max.fill", String(localized: "God eftermiddag med \(dog.name) 🐾"))
        case 17..<22: return ("sunset.fill", String(localized: "God kväll! Hur har dagen med \(dog.name) varit?"))
        default:      return ("moon.stars.fill", String(localized: "God natt – vila så ni orkar imorgon 🐾"))
        }
    }

    /// Milstolpe om födelsedagen är nära (inom 30 dagar).
    private var birthdayMilestone: String? {
        let now = calendar.startOfDay(for: .now)
        guard let next = calendar.nextDate(
            after: now.addingTimeInterval(-1),
            matching: calendar.dateComponents([.month, .day], from: dog.birthDate),
            matchingPolicy: .nextTime
        ) else { return nil }
        let days = calendar.dateComponents([.day], from: now, to: calendar.startOfDay(for: next)).day ?? 99
        guard days <= 30 else { return nil }
        // Räkna på årtalen, inte helår mellan datum: birthDate har en klockdel,
        // och fram till en födelsedag vid midnatt blir det strax under ett helt
        // år, vilket annars ger ett år för lite (0 i stället för 1).
        let turning = calendar.component(.year, from: next) - calendar.component(.year, from: dog.birthDate)
        if days == 0 { return String(localized: "🎂 Grattis \(dog.name) – \(turning) år idag!") }
        return days == 1
            ? String(localized: "🎂 \(dog.name) fyller \(turning) år imorgon")
            : String(localized: "🎂 \(dog.name) fyller \(turning) år om \(days) dagar")
    }

    /// Dagens tips – varierar per dag så det inte står stilla.
    private var dailyTip: String {
        let tips = [
            String(localized: "Tips: variera promenadrutten – nya dofter tröttar hjärnan mer än extra minuter."),
            String(localized: "Tips: kolla tassarna efter promenaden, särskilt mellan trampdynorna."),
            String(localized: "Tips: korta träningspass flera gånger om dagen slår ett långt."),
            String(localized: "Tips: färskt vatten alltid framme – särskilt varma dagar."),
            String(localized: "Tips: väg din hund regelbundet, små förändringar syns tidigast på vågen."),
            String(localized: "Tips: borsta tänderna eller ge tuggben – tandhälsa påverkar hela hunden."),
            String(localized: "Tips: låt hunden nosa klart ibland, det är mental motion.")
        ]
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: .now) ?? 1
        return tips[dayOfYear % tips.count]
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
            ? String(localized: "\(todaysTrainingMinutes) min motion loggad idag")
            : String(localized: "Ingen promenad loggad än — dags för en runda med \(dog.name)?")
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
            return (String(localized: "Löp pågår – dag \(day). Avsluta det i Kalender om det är över."), true)
        }
        return (String(localized: "Löp pågår – dag \(day) · \(HeatPhase.forDayInCycle(day).swedishCommon)"), false)
    }

    /// Skador som inte markerats som läkta. En läkt skada räknas inte längre
    /// som aktiv och faller därför bort från Hem. nil-status (äldre skada)
    /// räknas som aktiv.
    private var activeInjuries: [HealthEvent] {
        dog.healthEvents
            .filter { $0.type == .injury && $0.injuryStatus != .healed }
            .sorted { $0.date > $1.date }
    }

    /// Aktiv skada loggad de senaste 14 dagarna, annars nil.
    private var recentInjury: String? {
        let cutoff = calendar.date(byAdding: .day, value: -14, to: .now) ?? .now
        guard let injury = activeInjuries.first(where: { $0.date >= cutoff }) else { return nil }
        let status = injury.injuryStatus.map { " · \($0.displayName.lowercased())" } ?? ""
        return String(localized: "Skada: \(injury.title)\(status)")
    }

    private var allGood: Bool {
        todaysTrainingMinutes > 0
            && heatAgenda?.attention != true
            && recentInjury == nil
            && todayMeetups.isEmpty
            && nextMeetup == nil
            && dueTasksByTeam.isEmpty
    }

    /// Laddar dagens lokala aktivitet: träffar idag/snart och team-uppgifter
    /// som förfaller. Körs som en egen task så den inte blockerar resten av Hem.
    private func loadTodayActivity() async {
        guard let uid = authService.currentUserID else { return }
        let meetups = await TeamsRepository.shared.upcomingMeetups(uid: uid)
        todayMeetups = meetups.filter { calendar.isDateInToday($0.date) }
        if todayMeetups.isEmpty {
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
            nextMeetup = meetups
                .filter { $0.date > .now && $0.date <= weekEnd }
                .min { $0.date < $1.date }
        } else {
            nextMeetup = nil
        }

        // Uppgifter som förfaller idag eller är försenade, som jag inte bockat av.
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
        var due: [DueTasks] = []
        for team in await TeamsRepository.shared.myTeams(uid: uid) where team.kind.hasTasks {
            guard let teamID = team.id else { continue }
            let mine = await TeamsRepository.shared.tasks(teamID: teamID).filter { task in
                guard !task.isCompleted(by: uid), let dueDate = task.dueDate else { return false }
                return dueDate < endOfToday
            }
            if !mine.isEmpty { due.append(DueTasks(team: team, count: mine.count)) }
        }
        dueTasksByTeam = due
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
            icon: "scalemass.fill", category: String(localized: "Vikt"),
            value: latest.map { String(format: "%.1f kg", $0) } ?? String(localized: "Logga vikt"),
            delta: delta, deltaPositive: deltaPositive,
            subtitle: latest == nil ? String(localized: "Väg in \(dog.name) under Hälsa") : nil,
            tint: .blue
        )
    }

    private var motionTile: some View {
        let todaysMinutes = dog.trainingSessions
            .filter { calendar.isDateInToday($0.date) }
            .compactMap(\.durationMinutes)
            .reduce(0, +)
        return StatTile(
            icon: "figure.walk", category: String(localized: "Motion"),
            value: todaysMinutes > 0 ? "\(todaysMinutes) min" : "0 min",
            subtitle: todaysMinutes > 0 ? nil : String(localized: "Dags för en promenad? 🐾"),
            tint: .orange
        )
    }

    private var healthTile: some View {
        let injuries = activeInjuries
        let value = injuries.first?.title ?? String(localized: "Allt bra")
        return StatTile(
            icon: "heart.text.square.fill", category: String(localized: "Hälsa"), value: value,
            subtitle: injuries.first?.injuryStatus?.displayName,
            tint: injuries.isEmpty ? Theme.Colors.brand : Theme.Colors.warning
        )
    }

    private var heatTile: some View {
        let data = heatTileData
        return StatTile(
            icon: "drop.fill", category: String(localized: "Löp"), value: data.value,
            subtitle: data.subtitle, tint: .pink,
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
                return (String(localized: "Dag \(day)"), String(localized: "Avsluta löpet?"))
            }
            return (String(localized: "Dag \(day)"), HeatPhase.forDayInCycle(day).swedishCommon)
        }
        if let next = nextHeatDate, next > .now {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: .now),
                to: calendar.startOfDay(for: next)
            ).day ?? 0
            return (String(localized: "\(days) dagar"), String(localized: "till nästa löp"))
        }
        return (String(localized: "Ingen prognos än"), String(localized: "Registrera löp i Kalender"))
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
    @Environment(\.colorScheme) private var colorScheme
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
        .padding(Theme.Spacing.l)
        // Glas + lätt kategori-toning som tonar ut nedåt, med hårfin tintad
        // kant — ögat hittar rätt bricka utan att färgen skriker.
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                // Glas i mörkt läge, solid yta i ljust — se motiveringen i
                // TintedCardStyle (skugga över material låste huvudtråden).
                .fill(colorScheme == .dark
                      ? AnyShapeStyle(.ultraThinMaterial)
                      : AnyShapeStyle(Theme.Colors.cardBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .fill(LinearGradient(
                            colors: colorScheme == .dark
                                ? [tint.opacity(0.24), tint.opacity(0.06)]
                                : [tint.opacity(0.18), tint.opacity(0.05)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [tint.opacity(0.36), tint.opacity(0.12)]
                                    : [.white.opacity(0.90), tint.opacity(0.30)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: Theme.Colors.cardShadow(colorScheme, dark: 0.22), radius: colorScheme == .dark ? 10 : 12, y: 4)
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

// MARK: - Idag-karusell

/// Ett kort i Idag-karusellen. `destination` = nil betyder ambient kort som
/// inte är tryckbart (hälsning, tips, milstolpe).
private struct TodayCard: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let tint: Color
    let attention: Bool
    let destination: AnyView?
}

/// Roterar mellan Idag-korten. Auto-växlar var 6:e sekund; sveper användaren
/// själv stannar autorotationen (hen har tagit över).
private struct TodayCarousel: View {
    let cards: [TodayCard]

    @State private var index = 0
    /// Sant medan auto-rotationen själv flyttar index — så onChange kan
    /// skilja användarens svep (ta över) från rotationens egna steg.
    @State private var isAutoAdvancing = false
    @State private var userTookOver = false

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            TabView(selection: $index) {
                // Identitet per position, inte per UUID: korten räknas om vid
                // varje omritning, och nya UUID:n skulle annars bygga om
                // TabView och störa rotationen.
                ForEach(Array(cards.enumerated()), id: \.offset) { offset, card in
                    cardView(card).tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 96)

            if cards.count > 1 {
                HStack(spacing: 6) {
                    ForEach(cards.indices, id: \.self) { i in
                        Circle()
                            .fill(i == index ? Theme.Colors.brand : Theme.Colors.textSecondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .task(id: cards.count) {
            guard cards.count > 1 else { return }
            while !Task.isCancelled && !userTookOver {
                try? await Task.sleep(for: .seconds(6))
                if Task.isCancelled || userTookOver { break }
                isAutoAdvancing = true
                withAnimation(.easeInOut(duration: 0.4)) {
                    index = (index + 1) % max(cards.count, 1)
                }
                isAutoAdvancing = false
            }
        }
        .onChange(of: index) { _, _ in
            // Ändring som inte kom från rotations-tasken = användarens svep.
            // Då slutar vi rotera — kortet ska inte ryckas ur händerna.
            if !isAutoAdvancing { userTookOver = true }
        }
        .onChange(of: cards.count) { _, newCount in
            if index >= newCount { index = 0 }
        }
    }

    @ViewBuilder
    private func cardView(_ card: TodayCard) -> some View {
        if let destination = card.destination {
            NavigationLink { destination } label: { cardContent(card) }
                .buttonStyle(CardPressStyle())
        } else {
            cardContent(card)
        }
    }

    private func cardContent(_ card: TodayCard) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: card.icon)
                .font(.title2)
                .foregroundStyle(card.tint)
                .frame(width: 40)
            Text(card.text)
                .font(Theme.Typography.body.weight(card.attention ? .medium : .regular))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Theme.Spacing.s)
            if card.attention {
                Circle().fill(card.tint).frame(width: 7, height: 7)
            }
            if card.destination != nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        HemView(dog: Dog(name: "Sixten", breed: "Malinois", birthDate: .now, sex: .male))
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
