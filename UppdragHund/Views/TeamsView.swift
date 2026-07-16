//
//  TeamsView.swift
//  UppdragHund
//
//  Team & hundträffar: skapa team av vänner, planera träffar och svara
//  Kommer / Kan inte.
//

import SwiftUI

struct TeamsView: View {
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var teams: [Team] = []
    @State private var meetups: [Meetup] = []
    @State private var invites: [TeamInvite] = []
    @State private var isLoading = true
    @State private var isPresentingNewTeam = false
    @State private var isPresentingNewMeetup = false

    var body: some View {
        List {
            if !invites.isEmpty {
                Section("Team-inbjudningar") {
                    ForEach(invites) { invite in
                        TeamInviteRow(invite: invite) { Task { await load() } }
                    }
                }
            }
            meetupsSection
            teamsSection
        }
        .navigationTitle("Team & träffar")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewTeam, onDismiss: { Task { await load() } }) {
            NewTeamView()
        }
        .sheet(isPresented: $isPresentingNewMeetup, onDismiss: { Task { await load() } }) {
            NewMeetupView(teams: teams)
        }
    }

    private var meetupsSection: some View {
        Section {
            if meetups.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga träffar planerade. Skapa en och bjud in dina vänner!")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(meetups) { meetup in
                    MeetupRow(meetup: meetup, onChanged: { Task { await load() } })
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

    private var teamsSection: some View {
        Section {
            if teams.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga team än. Skapa ett och samla dina träningskompisar!")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(teams) { team in
                    NavigationLink {
                        TeamDetailView(team: team, onChanged: { Task { await load() } })
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(Theme.Colors.brand)
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
            Button {
                isPresentingNewTeam = true
            } label: {
                Label("Skapa team", systemImage: "plus")
            }
        } header: {
            Text("Mina team")
        }
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        async let loadedTeams = TeamsRepository.shared.myTeams(uid: uid)
        async let loadedMeetups = TeamsRepository.shared.upcomingMeetups(uid: uid)
        async let loadedInvites = TeamsRepository.shared.pendingInvites(for: uid)
        teams = await loadedTeams
        meetups = await loadedMeetups
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

// MARK: - Träff-rad med RSVP

struct MeetupRow: View {
    let meetup: Meetup
    var onChanged: () -> Void = {}

    @State private var authService = AuthService.shared
    @State private var isWorking = false

    private var myUid: String? { authService.currentUserID }
    private var myRSVP: MeetupRSVP {
        guard let myUid else { return .pending }
        return meetup.rsvp(for: myUid)
    }
    private var goingNames: String {
        meetup.goingUids.compactMap { meetup.invitedNames[$0] }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(meetup.title)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text(meetup.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                Text(meetup.locationName)
                if let teamName = meetup.teamName {
                    Text("· \(teamName)")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)

            if !goingNames.isEmpty {
                Text("Kommer: \(goingNames)")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.brand)
            }

            if let myUid, meetup.ownerUid != myUid {
                HStack(spacing: Theme.Spacing.m) {
                    Button {
                        rsvp(going: true)
                    } label: {
                        Label("Kommer", systemImage: myRSVP == .going ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(myRSVP == .going ? .green : Theme.Colors.brand)
                    Button {
                        rsvp(going: false)
                    } label: {
                        Label("Kan inte", systemImage: myRSVP == .declined ? "xmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(myRSVP == .declined ? .red : Theme.Colors.textSecondary)
                }
                .controlSize(.small)
                .disabled(isWorking)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }

    private func rsvp(going: Bool) {
        guard let uid = myUid, let id = meetup.id else { return }
        isWorking = true
        Task {
            try? await TeamsRepository.shared.setRSVP(meetupID: id, uid: uid, going: going)
            isWorking = false
            onChanged()
        }
    }
}

// MARK: - Nytt team

struct NewTeamView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var name = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Teamets namn", text: $name, prompt: Text("t.ex. Kvällspromenadgänget"))
                } footer: {
                    Text("Du lägger till medlemmar (dina vänner) inne i teamet efteråt.")
                }
            }
            .navigationTitle("Nytt team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skapa") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        guard let uid = authService.currentUserID else { return }
        isSaving = true
        Task {
            try? await TeamsRepository.shared.createTeam(
                name: name.trimmingCharacters(in: .whitespaces),
                ownerUid: uid,
                ownerName: currentUser.profile?.displayName ?? "Hundägare"
            )
            dismiss()
        }
    }
}

// MARK: - Teamdetalj

struct TeamDetailView: View {
    @State private var team: Team
    var onChanged: () -> Void = {}

    init(team: Team, onChanged: @escaping () -> Void = {}) {
        _team = State(initialValue: team)
        self.onChanged = onChanged
    }

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var friends: [UserProfile] = []
    @State private var isPresentingAdd = false
    @State private var confirmLeaveOrDelete = false
    @State private var errorMessage: String?
    @State private var invitedUids: Set<String> = []

    private var isOwner: Bool { authService.currentUserID == team.ownerUid }

    private var addableFriends: [UserProfile] {
        friends.filter { profile in
            guard let uid = profile.id else { return false }
            return !team.memberUids.contains(uid)
        }
    }

    var body: some View {
        List {
            Section("Medlemmar") {
                ForEach(team.memberUids, id: \.self) { uid in
                    HStack {
                        Text(team.memberNames[uid] ?? "Medlem")
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if uid == team.ownerUid {
                            Text("Ägare")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.brand.opacity(0.15), in: Capsule())
                                .foregroundStyle(Theme.Colors.brand)
                        }
                    }
                }
                if isOwner {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        Label("Bjud in vän", systemImage: "person.badge.plus")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmLeaveOrDelete = true
                } label: {
                    Text(isOwner ? "Ta bort teamet" : "Lämna teamet")
                }
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .task {
            guard let uid = authService.currentUserID else { return }
            friends = (try? await FriendsRepository.shared.friends(for: uid)) ?? []
        }
        .alert(
            "Något gick fel",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog(
            isOwner ? "Ta bort teamet?" : "Lämna teamet?",
            isPresented: $confirmLeaveOrDelete,
            titleVisibility: .visible
        ) {
            Button(isOwner ? "Ta bort" : "Lämna", role: .destructive) { leaveOrDelete() }
            Button("Avbryt", role: .cancel) {}
        }
        .sheet(isPresented: $isPresentingAdd) {
            NavigationStack {
                List(addableFriends) { friend in
                    Button {
                        add(friend)
                    } label: {
                        HStack {
                            ProfileAvatar(photoData: friend.photoData, size: 32)
                            Text(friend.displayName)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            if let uid = friend.id, invitedUids.contains(uid) {
                                Label("Inbjuden", systemImage: "paperplane.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.Colors.brand)
                            }
                        }
                    }
                    .disabled(friend.id.map { invitedUids.contains($0) } ?? false)
                }
                .overlay {
                    if addableFriends.isEmpty {
                        ContentUnavailableView(
                            "Inga fler vänner att bjuda in",
                            systemImage: "person.2",
                            description: Text("Alla dina vänner är redan med, eller så har du inga vänner än.")
                        )
                    }
                }
                .navigationTitle("Bjud in vän")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Klar") { isPresentingAdd = false }
                    }
                }
            }
        }
    }

    private func add(_ friend: UserProfile) {
        guard let teamID = team.id, let uid = friend.id,
              let myUid = authService.currentUserID else { return }
        Task {
            if await TeamsRepository.shared.hasPendingInvite(teamId: teamID, toUid: uid) {
                errorMessage = "\(friend.displayName) har redan en väntande inbjudan."
                return
            }
            do {
                try await TeamsRepository.shared.sendInvite(
                    team: team,
                    toUid: uid,
                    fromUid: myUid,
                    fromName: CurrentUserStore.shared.profile?.displayName ?? "Hundägare"
                )
                invitedUids.insert(uid)
            } catch {
                errorMessage = "Kunde inte bjuda in \(friend.displayName): \(error.localizedDescription)"
            }
        }
    }

    private func leaveOrDelete() {
        guard let teamID = team.id, let uid = authService.currentUserID else { return }
        Task {
            if isOwner {
                try? await TeamsRepository.shared.deleteTeam(teamID: teamID)
            } else {
                try? await TeamsRepository.shared.removeMember(teamID: teamID, uid: uid)
            }
            onChanged()
            dismiss()
        }
    }
}

// MARK: - Ny träff

struct NewMeetupView: View {
    let teams: [Team]

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

    private var selectedTeam: Team? {
        teams.first { $0.id == selectedTeamID }
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

                Section {
                    Picker("Team", selection: $selectedTeamID) {
                        Text("Inget team").tag(String?.none)
                        ForEach(teams) { team in
                            Text(team.name).tag(team.id)
                        }
                    }
                } header: {
                    Text("Bjud in")
                } footer: {
                    Text(selectedTeam != nil
                         ? "Alla i teamet bjuds in."
                         : "Välj ett team eller bocka i vänner nedan.")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skapa") { save() }.disabled(!canSave || isSaving)
                }
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
                invited: invited
            )
            dismiss()
        }
    }
}
