//
//  TeamsView.swift
//  UppdragHund
//
//  Team & hundträffar: skapa team av vänner, planera träffar och svara
//  Kommer / Kan inte.
//

import SwiftUI
import MapKit

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

    private var teamsSection: some View {
        Section {
            if teams.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga team än. Skapa ett och samla dina träningskompisar!")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(teams) { team in
                    NavigationLink {
                        TeamPageView(team: team, onChanged: { Task { await load() } })
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

    // Kartnål: sätts via platssökning eller tryck på kartan.
    @State private var pinLatitude: Double?
    @State private var pinLongitude: Double?
    @State private var searchResults: [MKMapItem] = []
    @State private var suppressSearch = false
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 62.0, longitude: 15.0),
        span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
    ))

    private var pinCoordinate: CLLocationCoordinate2D? {
        guard let pinLatitude, let pinLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: pinLatitude, longitude: pinLongitude)
    }

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
                    ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                        Button {
                            selectSearchResult(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name ?? "Plats")
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                if let subtitle = item.placemark.title {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    MapReader { proxy in
                        Map(position: $camera) {
                            if let pinCoordinate {
                                Marker(
                                    locationName.isEmpty ? "Träffen" : locationName,
                                    systemImage: "pawprint.fill",
                                    coordinate: pinCoordinate
                                )
                                .tint(Theme.Colors.brand)
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .onTapGesture { position in
                            if let coordinate = proxy.convert(position, from: .local) {
                                pinLatitude = coordinate.latitude
                                pinLongitude = coordinate.longitude
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Kartnål (valfritt)")
                } footer: {
                    Text(pinCoordinate == nil
                         ? "Skriv i Plats-fältet för att söka, eller tryck på kartan för att placera nålen."
                         : "Nålen är satt — tryck på kartan för att flytta den.")
                }
                .task(id: locationName) {
                    await searchLocations()
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

    /// Debouncad platssökning medan användaren skriver i Plats-fältet.
    private func searchLocations() async {
        if suppressSearch {
            suppressSearch = false
            return
        }
        let query = locationName.trimmingCharacters(in: .whitespaces)
        guard query.count >= 3 else {
            searchResults = []
            return
        }
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try? await MKLocalSearch(request: request).start()
        guard !Task.isCancelled else { return }
        searchResults = Array((response?.mapItems ?? []).prefix(4))
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        suppressSearch = true
        if let name = item.name { locationName = name }
        pinLatitude = coordinate.latitude
        pinLongitude = coordinate.longitude
        searchResults = []
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
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
                longitude: pinLongitude
            )
            dismiss()
        }
    }
}
