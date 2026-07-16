//
//  ForumView.swift
//  UppdragHund
//
//  Hundforumet: öppna diskussioner för alla användare. Lista → tråd med
//  svar, samt skapa ny diskussion. Rapportera/blockera via ModerationService.
//

import SwiftUI

struct ForumView: View {
    @State private var authService = AuthService.shared
    @State private var threads: [ForumThread] = []
    @State private var isLoading = true
    @State private var isPresentingNewThread = false
    @State private var threadPendingDelete: ForumThread?
    @State private var moderationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if threads.isEmpty {
                    Text(isLoading
                         ? "Laddar diskussioner…"
                         : "Inga diskussioner än. Starta den första — ställ en fråga eller dela ett träningstips!")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                            NavigationLink {
                                ForumThreadDetailView(thread: thread, onChanged: { Task { await load() } })
                            } label: {
                                threadRow(thread)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { threadMenu(thread) }
                            if index < threads.count - 1 {
                                Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationTitle("Forum")
        .navigationBarTitleDisplayMode(.inline)
        .bottomActionButton("Ny diskussion") {
            isPresentingNewThread = true
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewThread, onDismiss: { Task { await load() } }) {
            NewForumThreadView()
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
        .confirmationDialog(
            "Ta bort diskussionen?",
            isPresented: Binding(
                get: { threadPendingDelete != nil },
                set: { if !$0 { threadPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let thread = threadPendingDelete { delete(thread) }
                threadPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) { threadPendingDelete = nil }
        }
    }

    private func threadRow(_ thread: ForumThread) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(thread.title)
                .font(Theme.Typography.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
            Text(thread.text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)
            HStack(spacing: Theme.Spacing.s) {
                Text(thread.authorName)
                Text("·")
                Label("\(thread.replyCount)", systemImage: "bubble.left")
                Text("·")
                Text(thread.lastActivityAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func threadMenu(_ thread: ForumThread) -> some View {
        if thread.authorUid == authService.currentUserID {
            Button(role: .destructive) {
                threadPendingDelete = thread
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        } else {
            Button {
                report(thread)
            } label: {
                Label("Rapportera diskussion", systemImage: "flag")
            }
            Button(role: .destructive) {
                block(uid: thread.authorUid, name: thread.authorName)
            } label: {
                Label("Blockera \(thread.authorName)", systemImage: "hand.raised")
            }
        }
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        isLoading = true
        let blocked = await ModerationService.shared.refreshBlocked(for: uid)
        threads = await ForumRepository.shared.allThreads()
            .filter { !blocked.contains($0.authorUid) }
        isLoading = false
    }

    private func delete(_ thread: ForumThread) {
        guard let threadID = thread.id else { return }
        Task {
            try? await ForumRepository.shared.deleteThread(threadID)
            await load()
        }
    }

    private func report(_ thread: ForumThread) {
        guard let uid = authService.currentUserID, let threadID = thread.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "forumThread",
                contentID: threadID,
                contentText: "\(thread.title): \(thread.text)",
                authorUid: thread.authorUid,
                teamId: nil,
                postID: threadID,
                postAuthorUid: thread.authorUid,
                reporterUid: uid
            )
            moderationMessage = "Vi har tagit emot din anmälan och granskar innehållet."
        }
    }

    private func block(uid targetUid: String, name: String) {
        guard let uid = authService.currentUserID else { return }
        Task {
            try? await ModerationService.shared.block(uid: targetUid, name: name, by: uid)
            moderationMessage = "\(name) är blockerad. Du ser inte längre hens diskussioner eller svar. Du kan ångra det under Inställningar → Blockerade användare."
            await load()
        }
    }
}

// MARK: - Ny diskussion

struct NewForumThreadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var title = ""
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Rubrik", text: $title, prompt: Text("t.ex. Tips för valp som drar i kopplet?"))
                    TextField("Vad vill du diskutera?", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                } footer: {
                    Text("Diskussionen syns för alla som använder appen. Håll god ton. 🐾")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ny diskussion")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .bottomActionButton("Publicera", disabled: !canPost, isBusy: isSaving) {
                post()
            }
        }
    }

    private func post() {
        guard let uid = authService.currentUserID else { return }
        isSaving = true
        Task {
            do {
                try await ForumRepository.shared.createThread(
                    title: title.trimmingCharacters(in: .whitespaces),
                    text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    byUid: uid,
                    byName: currentUser.profile?.displayName ?? "Hundägare"
                )
                dismiss()
            } catch {
                errorMessage = "Kunde inte publicera: \(error.localizedDescription)"
                isSaving = false
            }
        }
    }
}

// MARK: - Trådvy

struct ForumThreadDetailView: View {
    let thread: ForumThread
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var replies: [ForumReply] = []
    @State private var replyText = ""
    @State private var isSending = false
    @State private var moderationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                // Trådstart
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(thread.title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(thread.text)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(thread.authorName) · \(thread.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // Svar
                if !replies.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(replies.enumerated()), id: \.element.id) { index, reply in
                            replyRow(reply)
                                .contextMenu { replyMenu(reply) }
                            if index < replies.count - 1 {
                                Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationTitle("Diskussion")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            replyBar
        }
        .task { await loadReplies() }
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
    }

    private func replyRow(_ reply: ForumReply) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(reply.text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("\(reply.authorName) · \(reply.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func replyMenu(_ reply: ForumReply) -> some View {
        if reply.authorUid == authService.currentUserID {
            Button(role: .destructive) {
                delete(reply)
            } label: {
                Label("Ta bort", systemImage: "trash")
            }
        } else {
            Button {
                report(reply)
            } label: {
                Label("Rapportera svar", systemImage: "flag")
            }
            Button(role: .destructive) {
                block(uid: reply.authorUid, name: reply.authorName)
            } label: {
                Label("Blockera \(reply.authorName)", systemImage: "hand.raised")
            }
        }
    }

    private var replyBar: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("Skriv ett svar…", text: $replyText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Button {
                sendReply()
            } label: {
                if isSending {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }

    private func loadReplies() async {
        guard let threadID = thread.id, let uid = authService.currentUserID else { return }
        let blocked = await ModerationService.shared.refreshBlocked(for: uid)
        replies = await ForumRepository.shared.replies(for: threadID)
            .filter { !blocked.contains($0.authorUid) }
    }

    private func sendReply() {
        guard let threadID = thread.id, let uid = authService.currentUserID else { return }
        isSending = true
        Task {
            try? await ForumRepository.shared.addReply(
                threadID: threadID,
                text: replyText.trimmingCharacters(in: .whitespacesAndNewlines),
                byUid: uid,
                byName: currentUser.profile?.displayName ?? "Hundägare"
            )
            replyText = ""
            isSending = false
            await loadReplies()
            onChanged()
        }
    }

    private func delete(_ reply: ForumReply) {
        guard let threadID = thread.id, let replyID = reply.id else { return }
        Task {
            try? await ForumRepository.shared.deleteReply(threadID: threadID, replyID: replyID)
            await loadReplies()
            onChanged()
        }
    }

    private func report(_ reply: ForumReply) {
        guard let uid = authService.currentUserID,
              let threadID = thread.id, let replyID = reply.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "forumReply",
                contentID: replyID,
                contentText: reply.text,
                authorUid: reply.authorUid,
                teamId: nil,
                postID: threadID,
                postAuthorUid: thread.authorUid,
                reporterUid: uid
            )
            moderationMessage = "Vi har tagit emot din anmälan och granskar innehållet."
        }
    }

    private func block(uid targetUid: String, name: String) {
        guard let uid = authService.currentUserID else { return }
        Task {
            try? await ModerationService.shared.block(uid: targetUid, name: name, by: uid)
            moderationMessage = "\(name) är blockerad. Du kan ångra det under Inställningar → Blockerade användare."
            await loadReplies()
        }
    }
}
