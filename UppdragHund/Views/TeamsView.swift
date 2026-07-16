//
//  TeamsView.swift
//  UppdragHund
//
//  Träffar-sidan (alla kommande träffar) och Team-sidan för den som inte
//  är med i något team än (inbjudningar + skapa nytt).
//

import SwiftUI
import MapKit

/// Träffar: alla kommande träffar jag ordnar eller är inbjuden till.
struct MeetupsListView: View {
    @State private var authService = AuthService.shared

    @State private var teams: [Team] = []
    @State private var meetups: [Meetup] = []
    @State private var isLoading = true
    @State private var isPresentingNewMeetup = false

    var body: some View {
        List {
            Section {
                if meetups.isEmpty {
                    Text(isLoading ? "Laddar…" : "Inga träffar planerade. Skapa en och bjud in dina vänner!")
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    ForEach(meetups) { meetup in
                        MeetupCard(meetup: meetup, onChanged: { Task { await load() } })
                    }
                }
                Button {
                    isPresentingNewMeetup = true
                } label: {
                    Label("Skapa träff", systemImage: "calendar.badge.plus")
                }
            } header: {
                Text("Kommande träffar")
            }
        }
        .navigationTitle("Träffar")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewMeetup, onDismiss: { Task { await load() } }) {
            NewMeetupView(teams: teams)
        }
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        async let loadedTeams = TeamsRepository.shared.myTeams(uid: uid)
        async let loadedMeetups = TeamsRepository.shared.upcomingMeetups(uid: uid)
        teams = await loadedTeams
        meetups = await loadedMeetups
        isLoading = false
        await NotificationService.syncMeetupReminders(for: uid)
    }
}

/// Team-sidan när man saknar team (eller har väntande inbjudningar):
/// acceptera en inbjudan eller skapa ett eget team.
struct JoinOrCreateTeamView: View {
    @State private var authService = AuthService.shared

    @State private var teams: [Team] = []
    @State private var invites: [TeamInvite] = []
    @State private var isLoading = true
    @State private var isPresentingNewTeam = false
    @State private var isPresentingJoinByCode = false

    var body: some View {
        List {
            if !invites.isEmpty {
                Section("Team-inbjudningar") {
                    ForEach(invites) { invite in
                        TeamInviteRow(invite: invite) { Task { await load() } }
                    }
                }
            }

            if !teams.isEmpty {
                Section("Dina team") {
                    ForEach(teams) { team in
                        NavigationLink {
                            TeamPageView(team: team, onChanged: { Task { await load() } })
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                if let photoData = team.photoData, let uiImage = UIImage(data: photoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 34, height: 34)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.3.fill")
                                        .foregroundStyle(Theme.Colors.brand)
                                        .frame(width: 34, height: 34)
                                        .background(Theme.Colors.brand.opacity(0.12), in: Circle())
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(team.name)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Text("\(team.memberCount) medlemmar")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    isPresentingJoinByCode = true
                } label: {
                    Label("Gå med med kod", systemImage: "qrcode")
                }
                Button {
                    isPresentingNewTeam = true
                } label: {
                    Label("Skapa team", systemImage: "plus")
                }
            } footer: {
                Text(teams.isEmpty && invites.isEmpty
                     ? "Har du fått en kod av din hundinstruktör? Välj Gå med med kod. Eller skapa ett eget team och bjud in dina vänner."
                     : "")
            }
        }
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewTeam, onDismiss: { Task { await load() } }) {
            NewTeamView()
        }
        .sheet(isPresented: $isPresentingJoinByCode, onDismiss: { Task { await load() } }) {
            JoinTeamByCodeView()
        }
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        async let loadedTeams = TeamsRepository.shared.myTeams(uid: uid)
        async let loadedInvites = TeamsRepository.shared.pendingInvites(for: uid)
        teams = await loadedTeams
        invites = await loadedInvites
        isLoading = false
    }
}

// MARK: - Inbjudningsrad (Acceptera / Avböj)

struct TeamInviteRow: View {
    let invite: TeamInvite
    var onResponded: () -> Void = {}

    @State private var currentUser = CurrentUserStore.shared
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(Theme.Colors.brand)
                Text(invite.teamName)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Text("\(invite.fromName) bjuder in dig")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            HStack(spacing: Theme.Spacing.m) {
                Button {
                    respond(accept: true)
                } label: {
                    Label("Acceptera", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.brand)
                Button {
                    respond(accept: false)
                } label: {
                    Label("Avböj", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.textSecondary)
            }
            .controlSize(.small)
            .disabled(isWorking)
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    private func respond(accept: Bool) {
        isWorking = true
        Task {
            try? await TeamsRepository.shared.respondToInvite(
                invite,
                accept: accept,
                myName: currentUser.profile?.displayName ?? "Hundägare"
            )
            isWorking = false
            onResponded()
        }
    }
}

// MARK: - Nytt team

struct NewTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var name = ""
    @State private var kind: TeamKind = .social
    @State private var isSaving = false
    @State private var isPresentingApplication = false

    /// Kurs- och konsulentteam kräver instruktörskonto (server-verifierat).
    private var isInstructor: Bool { currentUser.profile?.instructor == true }

    private func isLocked(_ option: TeamKind) -> Bool {
        option != .social && !isInstructor
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Teamets namn", text: $name, prompt: Text("t.ex. Kvällspromenadgänget"))
                }

                Section {
                    ForEach(TeamKind.allCases) { option in
                        Button {
                            if !isLocked(option) { kind = option }
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                Image(systemName: option.icon)
                                    .font(.title3)
                                    .foregroundStyle(isLocked(option) ? Theme.Colors.textSecondary : Theme.Colors.brand)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.displayName)
                                        .font(Theme.Typography.body.weight(.medium))
                                        .foregroundStyle(isLocked(option) ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                                    Text(isLocked(option) ? "Kräver instruktörskonto" : option.description)
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: isLocked(option)
                                      ? "lock.fill"
                                      : kind == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isLocked(option)
                                                     ? Theme.Colors.textSecondary.opacity(0.6)
                                                     : kind == option ? Theme.Colors.brand : Theme.Colors.textSecondary.opacity(0.4))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if !isInstructor {
                        Button {
                            isPresentingApplication = true
                        } label: {
                            Label("Ansök om instruktörskonto", systemImage: "graduationcap")
                                .foregroundStyle(Theme.Colors.brand)
                        }
                    }
                } header: {
                    Text("Vad är teamet för?")
                } footer: {
                    Text(isInstructor
                         ? "Typen styr vilka funktioner teamet har — en promenadgrupp slipper uppgifter och roller."
                         : "Hundkurs och konsulentverksamhet är för instruktörer — ansök så granskar vi och återkommer med en notis.")
                }
            }
            .navigationTitle("Nytt team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            }
            .bottomActionButton(
                "Skapa team",
                disabled: name.trimmingCharacters(in: .whitespaces).isEmpty,
                isBusy: isSaving
            ) {
                save()
            }
            .sheet(isPresented: $isPresentingApplication) {
                NewTicketView(kind: .instructor)
            }
            .task {
                // Färsk profil så en nybliven instruktör ser upplåsta val direkt.
                await currentUser.refresh()
            }
        }
    }

    private func save() {
        guard let uid = authService.currentUserID else { return }
        isSaving = true
        Task {
            try? await TeamsRepository.shared.createTeam(
                name: name.trimmingCharacters(in: .whitespaces),
                kind: kind,
                ownerUid: uid,
                ownerName: currentUser.profile?.displayName ?? "Hundägare"
            )
            dismiss()
        }
    }
}

// MARK: - Ny träff

struct NewMeetupView: View {
    let teams: [Team]

    init(teams: [Team], initialTeamID: String? = nil) {
        self.teams = teams
        _selectedTeamID = State(initialValue: initialTeamID)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var title = ""
    @State private var locationName = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var selectedTeamID: String?
    @State private var friends: [UserProfile] = []
    @State private var selectedFriendUids: Set<String> = []
    @State private var isSaving = false

    // Kurs: flera tillfällen med samma gäng + valfri platsgräns.
    @State private var isRecurring = false
    @State private var occurrences = 8
    @State private var intervalWeeks = 1
    @State private var hasMaxSpots = false
    @State private var maxSpots = 8

    // Kartnål: sätts via platssökning eller tryck på kartan (MeetupMapPickerSection).
    @State private var pinLatitude: Double?
    @State private var pinLongitude: Double?

    /// Bara team där jag får skapa träffar (kurs/konsulent: ägare/konsulent;
    /// vanlig grupp: alla medlemmar).
    private var selectableTeams: [Team] {
        teams.filter { $0.canCreateMeetups(authService.currentUserID) }
    }

    private var selectedTeam: Team? {
        selectableTeams.first { $0.id == selectedTeamID }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationName.trimmingCharacters(in: .whitespaces).isEmpty
            && (selectedTeam != nil || !selectedFriendUids.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Träff") {
                    TextField("Titel", text: $title, prompt: Text("t.ex. Söndagspromenad"))
                    TextField("Plats", text: $locationName, prompt: Text("t.ex. Pildammsparken"))
                    DatePicker("När", selection: $date, in: Date.now...)
                }

                MeetupMapPickerSection(
                    locationName: $locationName,
                    latitude: $pinLatitude,
                    longitude: $pinLongitude
                )

                Section {
                    Toggle("Flera tillfällen", isOn: $isRecurring.animation())
                    if isRecurring {
                        Stepper("Antal tillfällen: \(occurrences)", value: $occurrences, in: 2...12)
                        Picker("Intervall", selection: $intervalWeeks) {
                            Text("Varje vecka").tag(1)
                            Text("Varannan vecka").tag(2)
                        }
                    }
                    Toggle("Max antal platser", isOn: $hasMaxSpots.animation())
                    if hasMaxSpots {
                        Stepper("Platser: \(maxSpots)", value: $maxSpots, in: 2...50)
                    }
                } header: {
                    Text("Kurs (valfritt)")
                } footer: {
                    Text(isRecurring
                         ? "Skapar \(occurrences) träffar, \(intervalWeeks == 1 ? "en per vecka" : "varannan vecka"), med samma inbjudna. De inbjudna får en notis om hela serien."
                         : "En kurs är flera tillfällen med samma gäng — slå på Flera tillfällen.")
                }

                Section {
                    Picker("Team", selection: $selectedTeamID) {
                        Text("Inget team").tag(String?.none)
                        ForEach(selectableTeams) { team in
                            Text(team.name).tag(team.id)
                        }
                    }
                } header: {
                    Text("Bjud in")
                } footer: {
                    Text(selectedTeam != nil
                         ? "Alla i teamet bjuds in."
                         : "Välj ett team eller bocka i vänner nedan. I kurser och konsulentteam är det ägaren/konsulenter som skapar träffar.")
                }

                if selectedTeam == nil {
                    Section("Vänner") {
                        ForEach(friends) { friend in
                            if let uid = friend.id {
                                Button {
                                    if selectedFriendUids.contains(uid) {
                                        selectedFriendUids.remove(uid)
                                    } else {
                                        selectedFriendUids.insert(uid)
                                    }
                                } label: {
                                    HStack {
                                        ProfileAvatar(photoData: friend.photoData, size: 30)
                                        Text(friend.displayName)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Spacer()
                                        if selectedFriendUids.contains(uid) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Theme.Colors.brand)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ny träff")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            }
            .bottomActionButton("Skapa träff", disabled: !canSave, isBusy: isSaving) {
                save()
            }
            .task {
                guard let uid = authService.currentUserID else { return }
                friends = (try? await FriendsRepository.shared.friends(for: uid)) ?? []
            }
        }
    }

    private func save() {
        guard let uid = authService.currentUserID else { return }
        let myName = currentUser.profile?.displayName ?? "Hundägare"
        isSaving = true

        let invited: [(uid: String, name: String)]
        if let team = selectedTeam {
            invited = team.memberUids
                .filter { $0 != uid }
                .map { ($0, team.memberNames[$0] ?? "Vän") }
        } else {
            invited = friends
                .filter { friend in
                    guard let fuid = friend.id else { return false }
                    return selectedFriendUids.contains(fuid)
                }
                .compactMap { friend in
                    friend.id.map { ($0, friend.displayName) }
                }
        }

        Task {
            try? await TeamsRepository.shared.createMeetup(
                title: title.trimmingCharacters(in: .whitespaces),
                locationName: locationName.trimmingCharacters(in: .whitespaces),
                date: date,
                ownerUid: uid,
                ownerName: myName,
                team: selectedTeam,
                invited: invited,
                latitude: pinLatitude,
                longitude: pinLongitude,
                occurrences: isRecurring ? occurrences : 1,
                intervalWeeks: intervalWeeks,
                maxSpots: hasMaxSpots ? maxSpots : nil
            )
            dismiss()
        }
    }
}
