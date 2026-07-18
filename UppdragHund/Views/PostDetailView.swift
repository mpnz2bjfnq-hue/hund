//
//  PostDetailView.swift
//  UppdragHund
//
//  Visar ett inlägg med reaktioner (🐾) och kommentarer.
//

import SwiftUI
import SwiftData

struct PostDetailView: View {
    let post: ProfilePost
    var authorPhoto: Data? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var savedPlan = false
    @State private var liked = false
    @State private var moderationMessage: String?
    @State private var reactionCount = 0
    @State private var comments: [PostComment] = []
    @State private var newComment = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        postHeader
                        Text(post.text)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let photoData = post.photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        if let plan = post.trainingPlan {
                            planCard(plan)
                        }
                        reactionBar
                        Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                        commentsList
                    }
                    .padding(Theme.Spacing.l)
                }
                commentInputBar
            }
            .background(Theme.screenSurface)
            .navigationTitle("Inlägg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if post.authorUid != authService.currentUserID {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button {
                                reportPost()
                            } label: {
                                Label("Rapportera inlägg", systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                blockAuthor()
                            } label: {
                                Label("Blockera \(post.authorName)", systemImage: "hand.raised")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
            .alert(
                "Tack",
                isPresented: Binding(
                    get: { moderationMessage != nil },
                    set: { if !$0 { moderationMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(moderationMessage ?? "")
            }
        }
        .task { await load() }
    }

    private var postHeader: some View {
        HStack(spacing: Theme.Spacing.s) {
            ProfileAvatar(photoData: authorPhoto, size: 36)
                .tint(Theme.Colors.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(post.authorName)
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            if let dogName = post.dogName {
                Label(dogName, systemImage: "pawprint.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    private var reactionBar: some View {
        Button {
            Task { await toggleReaction() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: liked ? "pawprint.fill" : "pawprint")
                Text(reactionCount > 0 ? "\(reactionCount)" : "Gilla")
            }
            .font(Theme.Typography.body.weight(.medium))
            .foregroundStyle(liked ? Theme.Colors.brand : Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var commentsList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Kommentarer")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            if comments.isEmpty {
                Text("Inga kommentarer än. Var först!")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(comments) { comment in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(comment.authorName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Text(comment.text)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .contextMenu {
                        if comment.authorUid != authService.currentUserID {
                            Button {
                                reportComment(comment)
                            } label: {
                                Label("Rapportera kommentar", systemImage: "flag")
                            }
                        }
                    }
                }
            }
        }
    }

    private var commentInputBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("Skriv en kommentar…", text: $newComment, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                Task { await sendComment() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? Theme.Colors.brand : Theme.Colors.textSecondary)
            }
            .disabled(!canSend || isSending)
        }
        .padding(Theme.Spacing.m)
        .background(.bar)
    }

    private var canSend: Bool {
        !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func planCard(_ plan: SharedTrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Träningspass", systemImage: "list.bullet.rectangle.portrait")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.brand)
            Text(plan.title)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(plan.summaryLine)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(plan.exercises) { exercise in
                    HStack(alignment: .top) {
                        Text("•  \(exercise.name)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text(exercise.goalDescription)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(.vertical, 2)
            Button {
                savePlan(plan)
            } label: {
                Label(savedPlan ? "Sparat i biblioteket" : "Spara till mitt bibliotek",
                      systemImage: savedPlan ? "checkmark" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.brand)
            .disabled(savedPlan)
            .padding(.top, 4)
        }
        .padding()
        .background(Theme.Colors.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func savePlan(_ shared: SharedTrainingPlan) {
        // Kopian ägs av MIG (annars filtreras den bort av konto-scopet);
        // originalförfattarens namn behålls som referens.
        let plan = TrainingPlan(
            title: shared.title,
            note: shared.note,
            authorUid: authService.currentUserID,
            authorName: post.authorName
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
        try? modelContext.save()
        savedPlan = true
    }

    private func load() async {
        let blocked = ModerationService.shared.blockedUids
        comments = await PostsRepository.shared.comments(post: post)
            .filter { !blocked.contains($0.authorUid) }
        reactionCount = await PostsRepository.shared.reactionCount(post: post)
        if let uid = authService.currentUserID {
            liked = await PostsRepository.shared.hasReacted(post: post, uid: uid)
        }
    }

    private func reportPost() {
        guard let uid = authService.currentUserID, let postID = post.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "post", contentID: postID, contentText: post.text,
                authorUid: post.authorUid, teamId: post.teamId,
                postID: postID, postAuthorUid: post.authorUid, reporterUid: uid
            )
            moderationMessage = "Vi har tagit emot din anmälan och granskar innehållet."
        }
    }

    private func reportComment(_ comment: PostComment) {
        guard let uid = authService.currentUserID, let commentID = comment.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "comment", contentID: commentID, contentText: comment.text,
                authorUid: comment.authorUid, teamId: post.teamId,
                postID: post.id ?? "", postAuthorUid: post.authorUid, reporterUid: uid
            )
            moderationMessage = "Vi har tagit emot din anmälan och granskar innehållet."
        }
    }

    private func blockAuthor() {
        guard let uid = authService.currentUserID else { return }
        Task {
            try? await ModerationService.shared.block(uid: post.authorUid, name: post.authorName, by: uid)
            moderationMessage = "\(post.authorName) är blockerad. Hantera blockeringar under Inställningar."
        }
    }

    private func toggleReaction() async {
        guard let uid = authService.currentUserID else { return }
        let newLiked = !liked
        liked = newLiked
        reactionCount = max(0, reactionCount + (newLiked ? 1 : -1))
        do {
            try await PostsRepository.shared.setReaction(post: post, uid: uid, reacted: newLiked)
        } catch {
            // Ångra optimistiska ändringen vid fel.
            liked = !newLiked
            reactionCount = max(0, reactionCount + (newLiked ? -1 : 1))
        }
    }

    private func sendComment() async {
        guard canSend, let uid = authService.currentUserID else { return }
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = currentUser.profile?.displayName ?? "Du"
        isSending = true
        newComment = ""
        do {
            try await PostsRepository.shared.addComment(post: post, authorUid: uid, authorName: name, text: text)
            comments = await PostsRepository.shared.comments(post: post)
        } catch {
            newComment = text
        }
        isSending = false
    }
}
