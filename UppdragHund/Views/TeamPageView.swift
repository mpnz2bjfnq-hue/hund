//
//  TeamPageView.swift
//  UppdragHund
//
//  En riktig teamsida: teamets flöde, träffar och medlemmar samlade
//  bakom en segmentväljare, i samma kortstil som resten av appen.
//

import SwiftUI
import PhotosUI
import SwiftData

/// Identifiable-omslag så en medlems uid kan öppnas som profil-sheet.
private struct MemberProfileTarget: Identifiable {
    let id: String
}

struct TeamPageView: View {
    @State private var team: Team
    var onChanged: () -> Void = {}

    init(team: Team, startOnTasks: Bool = false, onChanged: @escaping () -> Void = {}) {
        _team = State(initialValue: team)
        _segment = State(initialValue: startOnTasks ? .tasks : .posts)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(ActiveDogStore.self) private var activeDogStore
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var segment: Segment = .posts
    /// Uppgifter vars pass redan sparats till biblioteket denna session.
    @State private var savedPlanTaskIDs: Set<String> = []
    /// Pass som öppnats från en uppgift (visas i sheet).
    @State private var planToOpen: TrainingPlan?
    @State private var posts: [ProfilePost] = []
    @State private var tasks: [TeamTask] = []
    @State private var meetups: [Meetup] = []
    @State private var memberPhotos: [String: Data] = [:]
    @State private var friends: [UserProfile] = []
    @State private var isLoading = true

    @State private var selectedPost: ProfilePost?
    /// Gilla-/kommentarsantal per inläggs-id.
    @State private var postCounts: [String: PostCounts] = [:]
    /// Foto öppnat i helskärm.
    @State private var fullScreenPhoto: FullScreenPhoto?
    @State private var postPendingDelete: ProfilePost?
    @State private var moderationMessage: String?
    @State private var isPresentingNewPost = false
    @State private var isPresentingNewTask = false
    /// Uppgift som redigeras (öppnar redigeringsvyn).
    @State private var taskToEdit: TeamTask?
    @State private var isPresentingJoinCode = false
    /// Medlem som ägaren är på väg att ta bort (bekräftas först).
    @State private var memberPendingRemoval: String?
    @State private var memberProfileTarget: MemberProfileTarget?
    /// Träff öppnad från en uppgifts träff-koppling.
    @State private var taskMeetup: Meetup?
    @State private var isPresentingNewMeetup = false
    @State private var isPresentingAdd = false
    @State private var confirmLeaveOrDelete = false
    @State private var errorMessage: String?
    @State private var invitedUids: Set<String> = []
    @State private var teamPhotoItem: PhotosPickerItem?
    @State private var teamCropCandidate: CropCandidate?

    private var isOwner: Bool { authService.currentUserID == team.ownerUid }

    private var addableFriends: [UserProfile] {
        friends.filter { profile in
            guard let uid = profile.id else { return false }
            return !team.memberUids.contains(uid)
        }
    }

    /// Flikar efter teamtyp — vanliga grupper slipper Uppgifter.
    private var availableSegments: [Segment] {
        Segment.allCases.filter { $0 != .tasks || team.kind.hasTasks }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header

                Picker("Visa", selection: $segment) {
                    ForEach(availableSegments) { segment in
                        Text(segment.title).tag(segment)
                    }
                }
                .pickerStyle(.segmented)

                // Mjuk växling mellan segmenten i stället för hårt byte.
                Group {
                    switch segment {
                    case .posts:   postsSection
                    case .tasks:   tasksSection
                    case .meetups: meetupsSection
                    case .members: membersSection
                    }
                }
                .id(segment)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .padding(Theme.Spacing.l)
            .animation(.spring(duration: 0.35), value: segment)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.screenSurface)
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewPost, onDismiss: { Task { await load() } }) {
            NewPostView(initialTeamID: team.id, lockTeam: true)
        }
        .sheet(isPresented: $isPresentingNewTask, onDismiss: { Task { await load() } }) {
            NewTeamTaskView(team: team, meetups: meetups)
        }
        .sheet(item: $taskToEdit, onDismiss: { Task { await load() } }) { task in
            NewTeamTaskView(team: team, meetups: meetups, editingTask: task)
        }
        .sheet(item: $taskMeetup) { meetup in
            MeetupDetailView(meetup: meetup, onChanged: { Task { await load() } })
        }
        .sheet(isPresented: $isPresentingJoinCode) {
            TeamInviteCodeSheet(team: team)
        }
        .sheet(isPresented: $isPresentingNewMeetup, onDismiss: { Task { await load() } }) {
            NewMeetupView(teams: [team], initialTeamID: team.id)
        }
        // Efter gilla/kommentera i detaljvyn ska siffrorna på kortet stämma.
        .sheet(item: $selectedPost, onDismiss: {
            Task { postCounts = await PostsRepository.shared.counts(for: posts) }
        }) { post in
            PostDetailView(post: post, authorPhoto: memberPhotos[post.authorUid])
        }
        .fullScreenCover(item: $fullScreenPhoto) { photo in
            FullScreenPhotoView(image: photo.image)
        }
        .sheet(isPresented: $isPresentingAdd) {
            inviteSheet
        }
        .sheet(item: $memberProfileTarget) { target in
            NavigationStack {
                ProfileView(userID: target.id)
            }
        }
        .sheet(item: $planToOpen) { plan in
            if let dog = activeDogStore.activeDog {
                NavigationStack {
                    TrainingPlanDetailView(plan: plan, dog: dog)
                }
            }
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
    }

    // MARK: - Header

    /// Hero-header i samma stil som hundkortet på Hem: teamfotot som
    /// bakgrund med gradient och stort namn; brandtonad platta utan foto.
    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ZStack(alignment: .bottomLeading) {
                if let data = team.photoData, let image = UIImage(data: data) {
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
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.Colors.brand.opacity(0.25))
                            .padding(Theme.Spacing.xl)
                    }
                }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.4),
                        .init(color: .black.opacity(0.35), location: 0.7),
                        .init(color: .black.opacity(0.9), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(team.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(team.memberCount) medlemmar")
                        .font(Theme.Typography.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(Theme.Spacing.l)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .adaptiveShadow(radius: 12, y: 5)
            .overlay(alignment: .topTrailing) {
                if isOwner {
                    PhotosPicker(selection: $teamPhotoItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.35), in: Circle())
                            .padding(Theme.Spacing.m)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Byt bild")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -8) {
                    ForEach(team.memberUids, id: \.self) { uid in
                        ProfileAvatar(photoData: memberPhotos[uid], size: 32)
                            .overlay(Circle().stroke(Theme.Colors.cardBackground, lineWidth: 2))
                    }
                }
                .padding(.horizontal, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: teamPhotoItem) {
            Task {
                // Öppna beskärningen med originalet — ägaren väljer själv
                // utsnitt och zoom innan bilden laddas upp.
                guard let item = teamPhotoItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                teamCropCandidate = CropCandidate(image: image)
                teamPhotoItem = nil
            }
        }
        .sheet(item: $teamCropCandidate) { candidate in
            ImageCropView(image: candidate.image, outputWidth: 900, aspect: 16 / 9, quality: 0.6) { cropped in
                Task {
                    guard let teamID = team.id else { return }
                    try? await TeamsRepository.shared.setTeamPhoto(teamID: teamID, photoData: cropped)
                    if let updated = await TeamsRepository.shared.team(id: teamID) {
                        team = updated
                    }
                    onChanged()
                }
            }
        }
    }

    /// Teamets avatar: foto om det finns, annars gruppikonen.
    private var teamAvatar: some View {
        Group {
            if let photoData = team.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.brand)
            }
        }
        .frame(width: 52, height: 52)
        .background(Theme.Colors.brand.opacity(0.12))
        .clipShape(Circle())
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
                        PostRowView(
                            post: post,
                            authorPhoto: memberPhotos[post.authorUid],
                            showsTeamChip: false,
                            counts: postCounts[post.id ?? ""] ?? PostCounts(),
                            onPhotoTap: { fullScreenPhoto = FullScreenPhoto(image: $0) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPost = post }
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
                            Divider()
                                .overlay(Theme.Colors.textSecondary.opacity(0.2))
                                .padding(.vertical, Theme.Spacing.m)
                        }
                    }
                }
                .cardStyle(padding: Theme.Spacing.m)
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

            if let plan = task.trainingPlan {
                taskPlanBox(plan, task: task)
            }

            if let meetupTitle = task.meetupTitle {
                taskMeetupBox(task, title: meetupTitle)
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
                Button {
                    taskToEdit = task
                } label: {
                    Label("Redigera uppgiften", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Label("Ta bort uppgiften", systemImage: "trash")
                }
            }
        }
    }

    /// Kopplat träningspass på en uppgift: tryck för att öppna passet,
    /// eller spara det till biblioteket.
    private func taskPlanBox(_ plan: SharedTrainingPlan, task: TeamTask) -> some View {
        let saved = task.id.map { savedPlanTaskIDs.contains($0) } ?? false

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button {
                openPlan(plan, from: task)
            } label: {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HStack {
                        Label(plan.title, systemImage: "list.bullet.rectangle.portrait")
                            .font(Theme.Typography.body.weight(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Text(plan.summaryLine)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    ForEach(plan.exercises) { exercise in
                        HStack(alignment: .top) {
                            Text("•  \(exercise.name)")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer(minLength: 8)
                            Text(exercise.goalDescription)
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                savePlan(plan, from: task)
            } label: {
                Label(saved ? "Sparat i biblioteket" : "Spara till mitt bibliotek",
                      systemImage: saved ? "checkmark" : "square.and.arrow.down")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(Theme.Colors.brand)
            .disabled(saved)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Kopplad träff på en uppgift: tryck för att öppna träffen med RSVP.
    /// Om träffen tagits bort visas bara den cachade titeln, otryckbar.
    private func taskMeetupBox(_ task: TeamTask, title: String) -> some View {
        let liveMeetup = meetups.first { $0.id == task.meetupId }

        return Button {
            if let liveMeetup { taskMeetup = liveMeetup }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "calendar.badge.clock")
                    .font(.body)
                    .foregroundStyle(Theme.Colors.brand)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Theme.Typography.body.weight(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if let date = task.meetupDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                if liveMeetup != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    Text("Borttagen")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(liveMeetup == nil)
    }

    /// Öppnar passet: återanvänder en befintlig kopia i biblioteket om en
    /// med samma titel redan finns, annars sparas en ny kopia först.
    private func openPlan(_ shared: SharedTrainingPlan, from task: TeamTask) {
        guard activeDogStore.activeDog != nil else {
            errorMessage = "Lägg till en hund först — passet körs för din aktiva hund."
            return
        }
        let title = shared.title
        let myUid = authService.currentUserID
        let descriptor = FetchDescriptor<TrainingPlan>(predicate: #Predicate { $0.title == title })
        let existing = (try? modelContext.fetch(descriptor))?
            .first { $0.authorUid == nil || $0.authorUid == myUid }
        planToOpen = existing ?? savePlan(shared, from: task)
    }

    /// Kopierar passet till mitt bibliotek (samma mönster som PostDetailView).
    @discardableResult
    private func savePlan(_ shared: SharedTrainingPlan, from task: TeamTask) -> TrainingPlan? {
        let plan = TrainingPlan(
            title: shared.title,
            note: shared.note,
            authorUid: authService.currentUserID,
            authorName: task.createdByName
        )
        modelContext.insert(plan)
        for (index, exercise) in shared.exercises.enumerated() {
            let entity = TrainingPlanExercise(
                name: exercise.name,
                targetMinutes: exercise.targetMinutes,
                reps: exercise.reps,
                targetMeters: exercise.targetMeters,
                instruction: exercise.instruction,
                order: index
            )
            entity.plan = plan
            modelContext.insert(entity)
        }
        if let message = modelContext.saveOrMessage() {
            errorMessage = message
            return nil
        }
        if let uid = authService.currentUserID {
            Task { await TrainingPlanBackupService.backup(plan, uid: uid) }
        }
        if let id = task.id {
            savedPlanTaskIDs.insert(id)
        }
        return plan
    }

    // MARK: - Träffar

    private var meetupsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if team.canCreateMeetups(authService.currentUserID) {
                Button {
                    isPresentingNewMeetup = true
                } label: {
                    Label("Skapa träff med teamet", systemImage: "calendar.badge.plus")
                        .font(Theme.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
            }

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
                        // Tryck på en medlem → profilen (där man kan lägga
                        // till varandra som vänner). Egen rad öppnar inget.
                        Button {
                            memberProfileTarget = MemberProfileTarget(id: uid)
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                ProfileAvatar(photoData: memberPhotos[uid], size: 36)
                                Text(team.memberNames[uid] ?? "Medlem")
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(uid == authService.currentUserID)
                        .accessibilityLabel("Visa profil för \(team.memberNames[uid] ?? "medlem")")
                        if uid == team.ownerUid {
                            roleBadge("Ägare", color: Theme.Colors.brand)
                        } else if team.isConsultant(uid) {
                            roleBadge("Konsulent", color: Theme.Colors.verified)
                        }
                        Spacer(minLength: 0)
                        if isOwner, uid != team.ownerUid {
                            Menu {
                                if team.kind.hasTasks {
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
                                }
                                Button(role: .destructive) {
                                    memberPendingRemoval = uid
                                } label: {
                                    Label("Ta bort ur teamet", systemImage: "person.fill.xmark")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            // På raden så bekräftelsen dyker upp intill den.
                            .confirmationDialog(
                                "Ta bort \(team.memberNames[uid] ?? "medlemmen") ur teamet?",
                                isPresented: Binding(
                                    get: { memberPendingRemoval == uid },
                                    set: { if !$0 { memberPendingRemoval = nil } }
                                ),
                                titleVisibility: .visible
                            ) {
                                Button("Ta bort", role: .destructive) {
                                    removeMember(uid: uid)
                                    memberPendingRemoval = nil
                                }
                                Button("Avbryt", role: .cancel) { memberPendingRemoval = nil }
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

            if team.kind.hasJoinCode, team.canManageTasks(authService.currentUserID) {
                Button {
                    isPresentingJoinCode = true
                } label: {
                    Label("Bjud in med kod", systemImage: "qrcode")
                        .font(Theme.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.brand)
            }

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
            // På knappen (inte vyn) så bekräftelsen dyker upp intill den.
            .confirmationDialog(
                isOwner ? "Ta bort teamet?" : "Lämna teamet?",
                isPresented: $confirmLeaveOrDelete,
                titleVisibility: .visible
            ) {
                Button(isOwner ? "Ta bort" : "Lämna", role: .destructive) { leaveOrDelete() }
                Button("Avbryt", role: .cancel) {}
            }
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
        postCounts = await PostsRepository.shared.counts(for: posts)
        await NotificationService.syncMeetupReminders(for: uid)
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

    private func removeMember(uid: String) {
        guard let teamID = team.id else { return }
        Task {
            do {
                try await TeamsRepository.shared.removeMember(teamID: teamID, uid: uid)
                team.memberUids.removeAll { $0 == uid }
                team.memberNames[uid] = nil
                team.consultantUids?.removeAll { $0 == uid }
                onChanged()
            } catch {
                errorMessage = "Kunde inte ta bort medlemmen: \(error.localizedDescription)"
            }
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
            do {
                if isOwner {
                    try await TeamsRepository.shared.deleteTeam(teamID: teamID)
                } else {
                    try await TeamsRepository.shared.leaveTeam(teamID: teamID, uid: uid)
                }
                onChanged()
                dismiss()
            } catch {
                // Stäng INTE vyn på fel — annars ser det ut som att man lämnat.
                errorMessage = isOwner
                    ? "Kunde inte ta bort teamet: \(error.localizedDescription)"
                    : "Kunde inte lämna teamet: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Ny uppgift

/// Konsulenten/ägaren lägger ut en uppgift till hela teamet.
struct NewTeamTaskView: View {
    let team: Team
    /// Teamets träffar — för att kunna koppla uppgiften till en träff.
    var meetups: [Meetup] = []
    /// Satt när vi redigerar en befintlig uppgift i stället för att skapa ny.
    var editingTask: TeamTask? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @Query(sort: \TrainingPlan.title) private var allPlans: [TrainingPlan]

    @State private var title = ""
    @State private var note = ""
    @State private var hasDueDate = false
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedPlanID: PersistentIdentifier?
    @State private var selectedMeetupID: String?
    @State private var isSaving = false
    @State private var didPrefill = false
    /// Uppgiften har ett kopplat pass som inte finns i mitt lokala bibliotek —
    /// då kan jag inte välja om det i listan, men det ska bevaras vid sparning.
    @State private var keepOriginalPlan = false

    private var isEditing: Bool { editingTask != nil }

    /// Bara mina egna pass kan kopplas.
    private var myPlans: [TrainingPlan] {
        allPlans.filter { $0.authorUid == nil || $0.authorUid == authService.currentUserID }
    }

    private var selectedPlan: TrainingPlan? {
        myPlans.first { $0.persistentModelID == selectedPlanID }
    }

    /// Kommande träffar, närmast först.
    private var upcomingMeetups: [Meetup] {
        meetups
            .filter { $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
    }

    private var selectedMeetup: Meetup? {
        upcomingMeetups.first { $0.id == selectedMeetupID }
    }

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

                if !myPlans.isEmpty {
                    Section {
                        Picker("Träningspass", selection: $selectedPlanID) {
                            Text("Inget").tag(PersistentIdentifier?.none)
                            ForEach(myPlans) { plan in
                                Text(plan.title).tag(Optional(plan.persistentModelID))
                            }
                        }
                    } header: {
                        Text("Koppla träningspass (valfritt)")
                    } footer: {
                        Text("Medlemmarna kan spara passet till sitt bibliotek och köra det direkt.")
                    }
                }

                if !upcomingMeetups.isEmpty {
                    Section {
                        Picker("Träff", selection: $selectedMeetupID) {
                            Text("Ingen").tag(String?.none)
                            ForEach(upcomingMeetups) { meetup in
                                Text("\(meetup.title) · \(meetup.date.formatted(date: .abbreviated, time: .omitted))")
                                    .tag(meetup.id)
                            }
                        }
                    } header: {
                        Text("Koppla träff (valfritt)")
                    } footer: {
                        Text("Uppgiften visar träffen, så alla vet vad ni ska öva på tills dess.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Redigera uppgift" : "Ny uppgift")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            }
            .bottomActionButton(
                isEditing ? "Spara ändringar" : "Lägg ut",
                disabled: title.trimmingCharacters(in: .whitespaces).isEmpty,
                isBusy: isSaving
            ) {
                save()
            }
            .onAppear(perform: prefillIfNeeded)
        }
    }

    /// Fyll i fälten från den uppgift som redigeras (en gång).
    private func prefillIfNeeded() {
        guard let task = editingTask, !didPrefill else { return }
        didPrefill = true
        title = task.title
        note = task.note ?? ""
        if let due = task.dueDate {
            hasDueDate = true
            dueDate = due
        }
        if let plan = task.trainingPlan {
            if let local = myPlans.first(where: { $0.title == plan.title }) {
                selectedPlanID = local.persistentModelID
            } else {
                keepOriginalPlan = true
            }
        }
        selectedMeetupID = task.meetupId
    }

    /// Kopplat pass som ska sparas: valt lokalt pass, annars det ursprungliga
    /// om det inte gick att välja i listan.
    private var resolvedPlan: SharedTrainingPlan? {
        if let selectedPlan { return selectedPlan.asShared() }
        if keepOriginalPlan, selectedPlanID == nil { return editingTask?.trainingPlan }
        return nil
    }

    private func save() {
        guard let teamID = team.id, let uid = authService.currentUserID else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue = trimmedNote.isEmpty ? nil : trimmedNote
        isSaving = true
        Task {
            if let task = editingTask, let taskID = task.id {
                try? await TeamsRepository.shared.updateTask(
                    teamID: teamID,
                    taskID: taskID,
                    title: trimmedTitle,
                    note: noteValue,
                    dueDate: hasDueDate ? dueDate : nil,
                    trainingPlan: resolvedPlan,
                    meetup: selectedMeetup
                )
            } else {
                try? await TeamsRepository.shared.createTask(
                    teamID: teamID,
                    title: trimmedTitle,
                    note: noteValue,
                    dueDate: hasDueDate ? dueDate : nil,
                    byUid: uid,
                    byName: currentUser.profile?.displayName ?? "Hundägare",
                    trainingPlan: resolvedPlan,
                    meetup: selectedMeetup
                )
            }
            dismiss()
        }
    }
}
