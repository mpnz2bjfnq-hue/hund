//
//  AdminPanelView.swift
//  UppdragHund
//
//  Adminpanel: översikts-statistik, anmälningskö, användarhantering och
//  broadcast-notiser. Syns bara för konton i config/admins; alla åtgärder
//  verifieras dessutom server-side (regler + callable functions).
//

import SwiftUI

struct AdminPanelView: View {
    @State private var stats = AdminService.AdminStats()
    @State private var isBackfilling = false
    @State private var backfillResult: String?

    private func runHandleBackfill() {
        isBackfilling = true
        backfillResult = nil
        Task {
            do {
                let result = try await AdminService.shared.backfillHandles()
                backfillResult = result.conflicts.isEmpty
                    ? "Klart: \(result.registered) registrerade, \(result.skipped) fanns redan."
                    : "Klart med \(result.conflicts.count) krock(ar): \(result.conflicts.joined(separator: "; "))"
            } catch {
                backfillResult = "Misslyckades: \(error.localizedDescription)"
            }
            isBackfilling = false
        }
    }

    var body: some View {
        List {
            Section("Översikt") {
                HStack(spacing: Theme.Spacing.m) {
                    statTile("\(stats.users)", "Användare", "person.2.fill")
                    statTile("\(stats.teams)", "Team", "person.3.fill")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                HStack(spacing: Theme.Spacing.m) {
                    statTile("\(stats.meetups)", "Träffar", "calendar")
                    statTile("\(stats.openReports)", "Anmälningar", "flag.fill",
                             tint: stats.openReports > 0 ? .orange : Theme.Colors.brand)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("Moderering") {
                NavigationLink {
                    AdminReportsView()
                } label: {
                    Label("Anmälningar", systemImage: "flag.badge.ellipsis")
                        .badge(stats.openReports)
                }
                NavigationLink {
                    AdminTicketsView()
                } label: {
                    Label("Supportärenden", systemImage: "ticket")
                        .badge(stats.openTickets)
                }
                NavigationLink {
                    AdminFeedbackView()
                } label: {
                    Label("Feedback", systemImage: "heart.text.square")
                        .badge(stats.feedback)
                }
                NavigationLink {
                    AdminInstructorApplicationsView()
                } label: {
                    Label("Instruktörsansökningar", systemImage: "graduationcap")
                }
                NavigationLink {
                    AdminUsersView()
                } label: {
                    Label("Användare", systemImage: "person.2")
                }
            }

            Section("Kommunikation") {
                NavigationLink {
                    AdminBroadcastView()
                } label: {
                    Label("Skicka notis till alla", systemImage: "megaphone")
                }
            }

            Section("Underhåll") {
                Button {
                    runHandleBackfill()
                } label: {
                    if isBackfilling {
                        HStack { ProgressView(); Text("Migrerar handles…") }
                    } else {
                        Label("Migrera @handles till registret", systemImage: "at.badge.plus")
                    }
                }
                .disabled(isBackfilling)
                if let backfillResult {
                    Text(backfillResult)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .navigationTitle("Adminpanel")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { stats = await AdminService.shared.fetchStats() }
        .task { stats = await AdminService.shared.fetchStats() }
    }

    private func statTile(_ value: String, _ label: String, _ icon: String, tint: Color = Theme.Colors.brand) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
        .cardStyle()
    }
}

// MARK: - Supportärenden (admin)

struct AdminTicketsView: View {
    @State private var tickets: [SupportTicket] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if tickets.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga supportärenden. 🎉")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(tickets) { ticket in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(ticket.subject)
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(ticket.isOpen ? "Öppet" : "Löst")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(ticket.isOpen ? .orange : Theme.Colors.brand)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    (ticket.isOpen ? Color.orange : Theme.Colors.brand).opacity(0.15),
                                    in: Capsule()
                                )
                        }
                        Text(ticket.message)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("\(ticket.name) · \(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        if ticket.isOpen {
                            Button {
                                resolve(ticket)
                            } label: {
                                Label("Markera som löst", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(Theme.Colors.brand)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(ticket)
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Supportärenden")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        tickets = await SupportService.shared.allTickets(kind: .support)
        isLoading = false
    }

    private func resolve(_ ticket: SupportTicket) {
        guard let id = ticket.id else { return }
        Task {
            try? await SupportService.shared.resolveTicket(id: id)
            await load()
        }
    }

    private func delete(_ ticket: SupportTicket) {
        guard let id = ticket.id else { return }
        Task {
            try? await SupportService.shared.deleteTicket(id: id)
            await load()
        }
    }
}

// MARK: - Feedback (admin)

struct AdminFeedbackView: View {
    @State private var items: [SupportTicket] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if items.isEmpty {
                Text(isLoading ? "Laddar…" : "Ingen feedback än.")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.subject)
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(item.message)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("\(item.name) · \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(item)
                        } label: {
                            Label("Ta bort", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        items = await SupportService.shared.allTickets(kind: .feedback)
        isLoading = false
    }

    private func delete(_ item: SupportTicket) {
        guard let id = item.id else { return }
        Task {
            try? await SupportService.shared.deleteTicket(id: id)
            await load()
        }
    }
}

// MARK: - Användarlista

// MARK: - Instruktörsansökningar (admin)

/// Godkänn eller avslå ansökningar om instruktörskonto. Godkännande sätter
/// den servervalidderade instructor-flaggan och skickar en gratulations-push.
struct AdminInstructorApplicationsView: View {
    @State private var tickets: [SupportTicket] = []
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if tickets.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga ansökningar. 🎉")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(tickets) { ticket in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(ticket.subject)
                                .font(.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Spacer()
                            Text(ticket.isOpen ? "Väntar" : "Hanterad")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(ticket.isOpen ? .orange : Theme.Colors.brand)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    (ticket.isOpen ? Color.orange : Theme.Colors.brand).opacity(0.15),
                                    in: Capsule()
                                )
                        }
                        Text(ticket.message)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("\(ticket.name) · \(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        if ticket.isOpen {
                            HStack(spacing: Theme.Spacing.s) {
                                Button {
                                    approve(ticket)
                                } label: {
                                    Label("Godkänn som instruktör", systemImage: "checkmark.seal.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(Theme.Colors.brand)

                                Button {
                                    decline(ticket)
                                } label: {
                                    Text("Avslå")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
                            }
                            .padding(.top, 2)
                            .disabled(isWorking)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .navigationTitle("Instruktörsansökningar")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        tickets = await SupportService.shared.allTickets(kind: .instructor)
        isLoading = false
    }

    private func approve(_ ticket: SupportTicket) {
        guard let id = ticket.id else { return }
        isWorking = true
        Task {
            do {
                try await AdminService.shared.setInstructor(targetUid: ticket.uid, instructor: true)
                try? await SupportService.shared.resolveTicket(id: id)
                await load()
                errorMessage = nil
            } catch {
                errorMessage = "Kunde inte godkänna: \(error.localizedDescription)"
            }
            isWorking = false
        }
    }

    private func decline(_ ticket: SupportTicket) {
        guard let id = ticket.id else { return }
        Task {
            try? await SupportService.shared.resolveTicket(id: id)
            await load()
        }
    }
}

struct AdminUsersView: View {
    @State private var users: [UserProfile] = []
    @State private var searchText = ""
    @State private var isLoading = true

    private var filtered: [UserProfile] {
        guard !searchText.isEmpty else { return users }
        return users.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.handle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                Text(isLoading ? "Laddar…" : "Inga användare hittades.")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(filtered) { user in
                    NavigationLink {
                        AdminUserDetailView(user: user)
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            ProfileAvatar(photoData: user.photoData, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(user.displayName)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("@\(user.handle) · \(user.dogSummaries?.count ?? 0) hundar")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Användare")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Sök namn eller @handle")
        .task {
            users = await AdminService.shared.listUsers()
            isLoading = false
        }
    }
}

// MARK: - Användardetalj (inlägg + radera konto)

struct AdminUserDetailView: View {
    let user: UserProfile

    @Environment(\.dismiss) private var dismiss
    @State private var posts: [ProfilePost] = []
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var message: String?
    @State private var isInstructor: Bool
    @State private var isTogglingInstructor = false

    init(user: UserProfile) {
        self.user = user
        _isInstructor = State(initialValue: user.instructor == true)
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Theme.Spacing.m) {
                    ProfileAvatar(photoData: user.photoData, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(user.displayName).font(.headline)
                            if isInstructor {
                                Image(systemName: "graduationcap.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.brand)
                            }
                        }
                        Text("@\(user.handle)")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("Medlem sedan \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }

            Section {
                Button {
                    toggleInstructor()
                } label: {
                    if isTogglingInstructor {
                        HStack { ProgressView(); Text("Uppdaterar…") }
                    } else {
                        Label(isInstructor ? "Ta bort instruktörskonto" : "Gör till instruktör",
                              systemImage: isInstructor ? "graduationcap" : "graduationcap.fill")
                    }
                }
                .disabled(isTogglingInstructor)
            } footer: {
                Text(isInstructor
                     ? "Instruktör: kan skapa hundkurser och konsulentteam. Befintliga team påverkas inte om du återkallar."
                     : "Instruktörer kan skapa hundkurser och konsulentteam. Personen får en push när du beviljar.")
            }

            Section("Inlägg (\(posts.count))") {
                if posts.isEmpty {
                    Text("Inga inlägg.")
                        .foregroundStyle(Theme.Colors.textSecondary)
                } else {
                    ForEach(posts) { post in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.text).lineLimit(3)
                            Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deletePost(post)
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    if isDeleting {
                        HStack { ProgressView(); Text("Raderar…") }
                    } else {
                        Text("Radera användarens konto")
                    }
                }
                .disabled(isDeleting)
            } footer: {
                Text("Raderar användarens konto och ALL data permanent. Går inte att ångra.")
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let uid = user.id {
                posts = (try? await PostsRepository.shared.posts(forUid: uid)) ?? []
            }
        }
        .confirmationDialog(
            "Radera \(user.displayName)s konto permanent?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Radera allt", role: .destructive) { deleteUser() }
            Button("Avbryt", role: .cancel) {}
        }
        .alert(
            "Admin",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func toggleInstructor() {
        guard let uid = user.id else { return }
        isTogglingInstructor = true
        Task {
            do {
                try await AdminService.shared.setInstructor(targetUid: uid, instructor: !isInstructor)
                isInstructor.toggle()
            } catch {
                message = "Kunde inte uppdatera: \(error.localizedDescription)"
            }
            isTogglingInstructor = false
        }
    }

    private func deletePost(_ post: ProfilePost) {
        Task {
            try? await PostsRepository.shared.delete(post: post)
            if let uid = user.id {
                posts = (try? await PostsRepository.shared.posts(forUid: uid)) ?? []
            }
        }
    }

    private func deleteUser() {
        guard let uid = user.id else { return }
        isDeleting = true
        Task {
            do {
                try await AdminService.shared.deleteUser(targetUid: uid)
                message = "Kontot är raderat."
            } catch {
                message = "Kunde inte radera: \(error.localizedDescription)"
            }
            isDeleting = false
        }
    }
}

// MARK: - Broadcast

struct AdminBroadcastView: View {
    @State private var title = ""
    @State private var body_ = ""
    @State private var isSending = false
    @State private var result: String?
    @State private var confirmSend = false

    var body: some View {
        Form {
            Section {
                TextField("Titel", text: $title, prompt: Text("t.ex. Ny version ute! 🎉"))
                TextField("Meddelande", text: $body_, axis: .vertical)
                    .lineLimit(2...5)
            } footer: {
                Text("Skickas som push-notis till ALLA användare med notiser påslagna.")
            }

            Section {
                Button {
                    confirmSend = true
                } label: {
                    if isSending {
                        HStack { ProgressView(); Text("Skickar…") }
                    } else {
                        Label("Skicka till alla", systemImage: "megaphone.fill")
                    }
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                          || body_.trimmingCharacters(in: .whitespaces).isEmpty
                          || isSending)
            }
        }
        .navigationTitle("Broadcast")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .confirmationDialog(
            "Skicka notisen till alla användare?",
            isPresented: $confirmSend,
            titleVisibility: .visible
        ) {
            Button("Skicka") { send() }
            Button("Avbryt", role: .cancel) {}
        }
        .alert(
            "Broadcast",
            isPresented: Binding(
                get: { result != nil },
                set: { if !$0 { result = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(result ?? "")
        }
    }

    private func send() {
        isSending = true
        Task {
            do {
                let outcome = try await AdminService.shared.broadcast(
                    title: title.trimmingCharacters(in: .whitespaces),
                    body: body_.trimmingCharacters(in: .whitespaces)
                )
                result = "Skickad till \(outcome.tokens) enheter (\(outcome.sent) levererade)."
                title = ""
                body_ = ""
            } catch {
                result = "Kunde inte skicka: \(error.localizedDescription)"
            }
            isSending = false
        }
    }
}
