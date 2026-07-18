//
//  CommunityPageView.swift
//  UppdragHund
//
//  En stadsgrupps sida: gå med / lämna, och stadens öppna hundträffar.
//  Medvetet enklare än en teamsida — ingen medlemslista (namnen är privata)
//  och inget textflöde att moderera, bara träffar som ger folk anledning att
//  ses. Man måste vara medlem för att skapa eller anmäla sig till en träff.
//

import SwiftUI

struct CommunityPageView: View {
    let community: Community

    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var memberCount = 0
    @State private var isMember = false
    @State private var meetups: [Meetup] = []
    @State private var isLoading = true
    @State private var isBusy = false
    @State private var isPresentingNewMeetup = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                meetupsSection
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.screenSurface)
        .navigationTitle(community.city)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: $isPresentingNewMeetup, onDismiss: { Task { await load() } }) {
            NewCommunityMeetupView(community: community)
        }
        .alert(
            "Något gick fel",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: "building.2.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.brand)
                    .frame(width: 52, height: 52)
                    .background(Theme.Colors.brand.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(community.name)
                        .font(Theme.Typography.sectionTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(memberCountText)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Button {
                toggleMembership()
            } label: {
                Group {
                    if isBusy {
                        ProgressView()
                    } else {
                        Text(isMember ? "Lämna gruppen" : "Gå med i gruppen")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(isMember ? Color.gray : Theme.Colors.brand)
            .disabled(isBusy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var memberCountText: String {
        memberCount == 1 ? "1 medlem" : "\(memberCount) medlemmar"
    }

    // MARK: - Träffar

    private var meetupsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Kommande träffar")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            if isMember {
                Button {
                    isPresentingNewMeetup = true
                } label: {
                    Label("Skapa träff i \(community.city)", systemImage: "calendar.badge.plus")
                        .font(Theme.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
            }

            if meetups.isEmpty {
                Text(isLoading
                     ? "Laddar…"
                     : isMember
                        ? "Inga träffar planerade än. Bli först att skapa en!"
                        : "Inga träffar planerade än. Gå med för att skapa en.")
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

                if !isMember {
                    Text("Gå med i gruppen för att anmäla dig till en träff.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Data

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        async let loadedCounts = CommunitiesRepository.shared.memberCounts()
        async let loadedMember = CommunitiesRepository.shared.isMember(communityID: community.id, uid: uid)
        async let loadedMeetups = CommunitiesRepository.shared.upcomingMeetups(communityID: community.id)
        memberCount = (await loadedCounts)[community.id] ?? 0
        isMember = await loadedMember
        meetups = await loadedMeetups
        isLoading = false
    }

    private func toggleMembership() {
        guard let uid = authService.currentUserID, !isBusy else { return }
        let wasMember = isMember
        isBusy = true
        // Optimistiskt — knappen och antalet svarar direkt, rullas tillbaka vid fel.
        isMember.toggle()
        memberCount = max(0, memberCount + (wasMember ? -1 : 1))

        Task {
            do {
                if wasMember {
                    try await CommunitiesRepository.shared.leave(communityID: community.id, uid: uid)
                } else {
                    try await CommunitiesRepository.shared.join(
                        communityID: community.id,
                        uid: uid,
                        displayName: currentUser.profile?.displayName ?? "Hundägare"
                    )
                }
            } catch {
                isMember = wasMember
                memberCount = max(0, memberCount + (wasMember ? 1 : -1))
                errorMessage = "Kunde inte \(wasMember ? "lämna" : "gå med"): \(error.localizedDescription)"
            }
            isBusy = false
        }
    }
}

// MARK: - Ny stadsträff

/// Enkel träffskapare för en stadsgrupp: titel, plats, tid och kartnål.
/// Ingen inbjudningslista — träffen är öppen för hela stadens medlemmar.
struct NewCommunityMeetupView: View {
    let community: Community

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var title = ""
    @State private var locationName = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var hasMaxSpots = false
    @State private var maxSpots = 12
    @State private var pinLatitude: Double?
    @State private var pinLongitude: Double?
    @State private var isSaving = false

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationName.trimmingCharacters(in: .whitespaces).isEmpty
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
                    Toggle("Max antal platser", isOn: $hasMaxSpots.animation())
                    if hasMaxSpots {
                        Stepper("Platser: \(maxSpots)", value: $maxSpots, in: 2...50)
                    }
                } footer: {
                    Text("Träffen är öppen för alla medlemmar i \(community.name).")
                }
            }
            .navigationTitle("Ny träff i \(community.city)")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            }
            .bottomActionButton("Skapa träff", disabled: !canSave, isBusy: isSaving) {
                save()
            }
        }
    }

    private func save() {
        guard let uid = authService.currentUserID else { return }
        isSaving = true
        Task {
            do {
                try await CommunitiesRepository.shared.createMeetup(
                    community: community,
                    title: title.trimmingCharacters(in: .whitespaces),
                    locationName: locationName.trimmingCharacters(in: .whitespaces),
                    date: date,
                    ownerUid: uid,
                    ownerName: currentUser.profile?.displayName ?? "Hundägare",
                    latitude: pinLatitude,
                    longitude: pinLongitude,
                    maxSpots: hasMaxSpots ? maxSpots : nil
                )
                dismiss()
            } catch {
                isSaving = false
            }
        }
    }
}
