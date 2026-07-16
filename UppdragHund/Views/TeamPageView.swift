//
//  TeamPageView.swift
//  UppdragHund
//
//  En riktig teamsida: teamets flöde, träffar och medlemmar samlade
//  bakom en segmentväljare, i samma kortstil som resten av appen.
//

import SwiftUI

struct TeamPageView: View {
    @State private var team: Team
    var onChanged: () -> Void = {}

    init(team: Team, onChanged: @escaping () -> Void = {}) {
        _team = State(initialValue: team)
        self.onChanged = onChanged
    }

    private enum Segment: String, CaseIterable, Identifiable {
        case posts, tasks, meetups, members
        var id: String { rawValue }
        var title: String {
            switch self {
            case .posts:   "Inlägg"
            case .tasks:   "Uppgifter"
            case .meetups: "Träffar"
            case .members: "Medlemmar"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var segment: Segment = .posts
    @State private var posts: [ProfilePost] = []
    @State private var tasks: [TeamTask] = []
    @State private var meetups: [Meetup] = []
    @State private var memberPhotos: [String: Data] = [:]
    @State private var friends: [UserProfile] = []
    @State private var isLoading = true

    @State private var selectedPost: ProfilePost?
    @State private var postPendingDelete: ProfilePost?
    @State private var moderationMessage: String?
    @State private var isPresentingNewPost = false
    @State private var isPresentingNewTask = false
    @State private var isPresentingNewMeetup = false
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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                Picker("Visa", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)

                switch segment {
                case .posts:   postsSection
                case .tasks:   tasksSection
                case .meetups: meetupsSection
                case .members: membersSection
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewPost, onDismiss: { Task { await load() } }) {
            NewPostView(initialTeamID: team.id, lockTeam: true)
        }
        .sheet(isPresented: $isPresentingNewTask, onDismiss: { Task { await load() } }) {
            NewTeamTaskView(team: team)
        }
        .sheet(isPresented: $isPresentingNewMeetup, onDismiss: { Task { await load() } }) {
            NewMeetupView(teams: [team], initialTeamID: team.id)
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post, authorPhoto: memberPhotos[post.authorUid])
        }
        .sheet(isPresented: $isPresentingAdd) {
            inviteSheet
        }
        .alert(
            "Tack för din anmälan",
            isPresented: Binding(
                get: { moderationMessage != nil },
                set: { if !$0 { moderationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(moderationMessage ?? "")
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
            "Ta bort inlägget?",
            isPresented: Binding(
                get: { postPendingDelete != nil },
                set: { if !$0 { postPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let post = postPendingDelete { deletePost(post) }
                postPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) { postPendingDelete = nil }
        }
        .confirmationDialog(
            isOwner ? "Ta bort teamet?" : "Lämna teamet?",
            isPresented: $confirmLeaveOrDelete,
            titleVisibility: .visible
        ) {
            Button(isOwner ? "Ta bort" : "Lämna", role: .destructive) { leaveOrDelete() }
            Button("Avbryt", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.brand)
                    .frame(width: 52, height: 52)
                    .background(Theme.Colors.brand.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(Theme.Typography.sectionTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(team.memberCount) medlemmar · Ägare: \(team.memberNames[team.ownerUid] ?? team.ownerName)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -8) {
                    ForEach(team.memberUids, id: \.self) { uid in
                        ProfileAvatar(photoData: memberPhotos[uid], size: 32)
                            .overlay(Circle().stroke(Theme.Colors.cardBackground, lineWidth: 2))
                    }
                }
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Inlägg

    private var postsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button {
                isPresentingNewPost = true
            } label: {
                Label("Skriv inlägg till teamet", systemImage: "square.and.pencil")
                    .font(Theme.Typography.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.Colors.brand)

            if posts.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga inlägg i teamet än. Bli först att dela något!")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                        Button {
                            selectedPost = post
                        } label: {
                            PostRowView(
                                post: post,
                                authorPhoto: memberPhotos[post.authorUid],
                                showsTeamChip: false
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if post.authorUid == authService.currentUserID {
                                Button(role: .destructive) {
                                    postPendingDelete = post
                                } label: {
                                    Label("Ta bort", systemImage: "trash")
                                }
                            } else {
                                Button {
                                    report(post)
                                } label: {
                                    Label("Rapportera inlägg", systemImage: "flag")
                                }
                            }
                        }
                        if index < posts.count - 1 {
                            Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Uppgifter

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if team.canManageTasks(authService.currentUserID) {
                Button {
                    isPresentingNewTask = true
                } label: {
                    Label("Lägg ut uppgift", systemImage: "checklist")
                        .font(Theme.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
            }

            if tasks.isEmpty {
                Text(isLoading
                     ? "Laddar…"
                     : team.canManageTasks(authService.currentUserID)
                        ? "Inga uppgifter än. Lägg ut något teamet ska träna på!"
                        : "Inga uppgifter än. Teamets ägare eller konsulent kan lägga ut uppgifter här.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                ForEach(tasks) { task in
                    taskCard(task)
                }
            }
        }
    }

    private func taskCard(_ task: TeamTask) -> some View {
        let myUid = authService.currentUserID
        let doneByMe = task.isCompleted(by: myUid)
        let doneNames = task.completedUids.compactMap { team.memberNames[$0] }

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Utlagd av \(task.createdByName)")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 8)
                if let dueDate = task.dueDate {
                    Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(dueDate < .now ? Theme.Colors.warning : Theme.Colors.textSecondary)
                }
            }

            if let note = task.note, !note.isEmpty {
                Text(note)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(task.completedUids.count) av \(team.memberCount) klara")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.brand)
                    if !doneNames.isEmpty {
                        Text(doneNames.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                Button {
                    toggleTask(task, done: !doneByMe)
                } label: {
                    Label(doneByMe ? "Klar" : "Markera klar",
                          systemImage: doneByMe ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(doneByMe ? .green : Theme.Colors.brand)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .contextMenu {
            if team.canManageTasks(myUid) || task.createdByUid == myUid {
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Label("Ta bort uppgiften", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Träffar

    private var meetupsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Button {
                isPresentingNewMeetup = true
            } label: {
                Label("Skapa träff med teamet", systemImage: "calendar.badge.plus")
                    .font(Theme.Typography.body.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(Theme.Colors.brand)

            if meetups.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga träffar planerade för teamet.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(meetups.enumerated()), id: \.element.id) { index, meetup in
                        MeetupCard(meetup: meetup, onChanged: { Task { await load() } })
                        if index < meetups.count - 1 {
                            Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Medlemmar

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(spacing: 0) {
                ForEach(Array(team.memberUids.enumerated()), id: \.element) { index, uid in
                    HStack(spacing: Theme.Spacing.m) {
                        ProfileAvatar(photoData: memberPhotos[uid], size: 36)
                        Text(team.memberNames[uid] ?? "Medlem")
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if uid == team.ownerUid {
                            roleBadge("Ägare", color: Theme.Colors.brand)
                        } else if team.isConsultant(uid) {
                            roleBadge("Konsulent", color: Theme.Colors.verified)
                        }
                        Spacer(minLength: 0)
                        if isOwner, uid != team.ownerUid {
                            Menu {
                                if team.isConsultant(uid) {
                                    Button {
                                        setConsultant(uid: uid, isConsultant: false)
                                    } label: {
                                        Label("Ta bort som konsulent", systemImage: "person.badge.minus")
                                    }
                                } else {
                                    Button {
                                        setConsultant(uid: uid, isConsultant: true)
                                    } label: {
                                        Label("Gör till konsulent", systemImage: "person.badge.shield.checkmark")
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                    if index < team.memberUids.count - 1 {
                        Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                    }
                }
            }
            .cardStyle()

            if isOwner {
                Button {
                    isPresentingAdd = true
                } label: {
                    Label("Bjud in vän", systemImage: "person.badge.plus")
                        .font(Theme.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
            }

            Button(role: .destructive) {
                confirmLeaveOrDelete = true
            } label: {
                Text(isOwner ? "Ta bort teamet" : "Lämna teamet")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }

    private func roleBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    // MARK: - Bjud in-sheet

    private var inviteSheet: some View {
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

    // MARK: - Data

    private func load() async {
        guard let uid = authService.currentUserID, let teamID = team.id else { return }
        async let loadedPosts = PostsRepository.shared.teamPosts(teamId: teamID)
        async let loadedTasks = TeamsRepository.shared.tasks(teamID: teamID)
        async let loadedMeetups = TeamsRepository.shared.upcomingMeetups(uid: uid)
        async let blocked = ModerationService.shared.refreshBlocked(for: uid)
        async let refreshedTeam = TeamsRepository.shared.team(id: teamID)

        let blockedUids = await blocked
        posts = await loadedPosts.filter { !blockedUids.contains($0.authorUid) }
        tasks = await loadedTasks
        meetups = await loadedMeetups.filter { $0.teamId == teamID }
        friends = (try? await FriendsRepository.shared.friends(for: uid)) ?? []
        if let refreshed = await refreshedTeam {
            team = refreshed
        }

        var photos: [String: Data] = [:]
        if let myPhoto = currentUser.profile?.photoData {
            photos[uid] = myPhoto
        }
        for friend in friends {
            if let friendUid = friend.id, let photo = friend.photoData {
                photos[friendUid] = photo
            }
        }
        memberPhotos = photos
        isLoading = false
    }

    private func deletePost(_ post: ProfilePost) {
        Task {
            try? await PostsRepository.shared.delete(post: post)
            await load()
        }
    }

    private func report(_ post: ProfilePost) {
        guard let uid = authService.currentUserID, let postID = post.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "post",
                contentID: postID,
                contentText: post.text,
                authorUid: post.authorUid,
                teamId: post.teamId,
                postID: postID,
                postAuthorUid: post.authorUid,
                reporterUid: uid
            )
            moderationMessage = "Inlägget är rapporterat och granskas."
        }
    }

    private func setConsultant(uid: String, isConsultant: Bool) {
        guard let teamID = team.id else { return }
        Task {
            do {
                try await TeamsRepository.shared.setConsultant(teamID: teamID, uid: uid, isConsultant: isConsultant)
                var updated = team.consultantUids ?? []
                if isConsultant {
                    updated.append(uid)
                } else {
                    updated.removeAll { $0 == uid }
                }
                team.consultantUids = updated
            } catch {
                errorMessage = "Kunde inte ändra rollen: \(error.localizedDescription)"
            }
        }
    }

    private func toggleTask(_ task: TeamTask, done: Bool) {
        guard let teamID = team.id, let taskID = task.id,
              let uid = authService.currentUserID else { return }
        // Optimistisk uppdatering så bocken känns direkt.
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            if done {
                tasks[index].completedUids.append(uid)
            } else {
                tasks[index].completedUids.removeAll { $0 == uid }
            }
        }
        Task {
            do {
                try await TeamsRepository.shared.setTaskCompleted(
                    teamID: teamID, taskID: taskID, uid: uid, completed: done
                )
            } catch {
                errorMessage = "Kunde inte spara: \(error.localizedDescription)"
                await load()
            }
        }
    }

    private func deleteTask(_ task: TeamTask) {
        guard let teamID = team.id, let taskID = task.id else { return }
        Task {
            try? await TeamsRepository.shared.deleteTask(teamID: teamID, taskID: taskID)
            await load()
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
                    fromName: currentUser.profile?.displayName ?? "Hundägare"
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

// MARK: - Ny uppgift

/// Konsulenten/ägaren lägger ut en uppgift till hela teamet.
struct NewTeamTaskView: View {
    let team: Team

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var title = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vad ska göras?", text: $title, prompt: Text("t.ex. Träna inkallning 10 min/dag"))
                    TextField("Beskrivning (valfritt)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("Alla i \(team.name) ser uppgiften och bockar av när de är klara.")
                }

                Section {
                    Toggle("Slutdatum", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Klar senast", selection: $dueDate, in: Date.now..., displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Ny uppgift")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lägg ut") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        guard let teamID = team.id, let uid = authService.currentUserID else { return }
        isSaving = true
        Task {
            try? await TeamsRepository.shared.createTask(
                teamID: teamID,
                title: title.trimmingCharacters(in: .whitespaces),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil
                    : note.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: hasDueDate ? dueDate : nil,
                byUid: uid,
                byName: currentUser.profile?.displayName ?? "Hundägare"
            )
            dismiss()
        }
    }
}
