//
//  MeetupViews.swift
//  UppdragHund
//
//  Evenemangskort för träffar + detaljvy med karta och Kommer/Kan inte.
//

import SwiftUI
import MapKit

// MARK: - Evenemangskort

struct MeetupCard: View {
    let meetup: Meetup
    var onChanged: () -> Void = {}

    @State private var authService = AuthService.shared
    @State private var isPresentingDetail = false

    private var myRSVP: MeetupRSVP {
        guard let uid = authService.currentUserID else { return .pending }
        return meetup.rsvp(for: uid)
    }

    private var isOwner: Bool { authService.currentUserID == meetup.ownerUid }

    var body: some View {
        Button {
            isPresentingDetail = true
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                VStack(spacing: 0) {
                    Text(meetup.date.formatted(.dateTime.day()))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.Colors.brand)
                    Text(meetup.date.formatted(.dateTime.month(.abbreviated)))
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(width: 48, height: 48)
                .background(Theme.Colors.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.title)
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: meetup.latitude != nil ? "mappin.and.ellipse" : "mappin")
                        Text(meetup.locationName)
                            .lineLimit(1)
                        Text("· \(meetup.date.formatted(date: .omitted, time: .shortened))")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    if let seriesLabel = meetup.seriesLabel {
                        Text(seriesLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    HStack(spacing: Theme.Spacing.s) {
                        Text(meetup.maxSpots.map { "\(meetup.goingUids.count) av \($0) platser" }
                             ?? "\(meetup.goingUids.count) kommer")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.brand)
                        if meetup.isFull {
                            chip("Fullt", color: Theme.Colors.warning)
                        }
                        statusChip
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.vertical, Theme.Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresentingDetail) {
            MeetupDetailView(meetup: meetup, onChanged: onChanged)
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        if isOwner {
            chip("Din träff", color: Theme.Colors.brand)
        } else {
            switch myRSVP {
            case .going:    chip("Du kommer ✓", color: .green)
            case .declined: chip("Kan inte", color: .red)
            case .pending:  chip("Osvarat", color: Theme.Colors.warning)
            }
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Kartväljare (delas av Ny träff och Ändra träff)

/// Form-sektion med platssökning + karta där nålen placeras/flyttas.
/// Söker medan användaren skriver i det bundna Plats-fältet.
struct MeetupMapPickerSection: View {
    @Binding var locationName: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @State private var searchResults: [MKMapItem] = []
    @State private var suppressSearch: Bool
    @State private var camera: MapCameraPosition

    init(locationName: Binding<String>, latitude: Binding<Double?>, longitude: Binding<Double?>) {
        _locationName = locationName
        _latitude = latitude
        _longitude = longitude
        // Vid redigering finns redan namn/nål — sök inte direkt, och centrera på nålen.
        _suppressSearch = State(initialValue: !locationName.wrappedValue.isEmpty)
        if let lat = latitude.wrappedValue, let lng = longitude.wrappedValue {
            _camera = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )))
        } else {
            _camera = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 62.0, longitude: 15.0),
                span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 12)
            )))
        }
    }

    private var pinCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        Section {
            ForEach(Array(searchResults.enumerated()), id: \.offset) { _, item in
                Button {
                    select(item)
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
                        latitude = coordinate.latitude
                        longitude = coordinate.longitude
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
            await search()
        }
    }

    private func search() async {
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

    private func select(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        suppressSearch = true
        if let name = item.name { locationName = name }
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        searchResults = []
        withAnimation {
            camera = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        }
    }
}

// MARK: - Ändra träff (endast ägaren)

struct EditMeetupView: View {
    let meetup: Meetup
    /// Får den uppdaterade träffen efter lyckad sparning.
    var onSaved: (Meetup) -> Void = { _ in }

    init(meetup: Meetup, onSaved: @escaping (Meetup) -> Void = { _ in }) {
        self.meetup = meetup
        self.onSaved = onSaved
        _title = State(initialValue: meetup.title)
        _locationName = State(initialValue: meetup.locationName)
        _date = State(initialValue: meetup.date)
        _latitude = State(initialValue: meetup.latitude)
        _longitude = State(initialValue: meetup.longitude)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var locationName: String
    @State private var date: Date
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !locationName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Träff") {
                    TextField("Titel", text: $title)
                    TextField("Plats", text: $locationName)
                    DatePicker("När", selection: $date, in: Date.now...)
                }

                MeetupMapPickerSection(
                    locationName: $locationName,
                    latitude: $latitude,
                    longitude: $longitude
                )
            }
            .navigationTitle("Ändra träff")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
            }
            .bottomActionButton("Spara", disabled: !canSave, isBusy: isSaving) {
                save()
            }
            .alert(
                "Kunde inte spara",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        guard let id = meetup.id else { return }
        isSaving = true
        Task {
            do {
                let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
                let trimmedLocation = locationName.trimmingCharacters(in: .whitespaces)
                try await TeamsRepository.shared.updateMeetup(
                    meetupID: id,
                    title: trimmedTitle,
                    locationName: trimmedLocation,
                    date: date,
                    latitude: latitude,
                    longitude: longitude
                )
                var updated = meetup
                updated.title = trimmedTitle
                updated.locationName = trimmedLocation
                updated.date = date
                updated.latitude = latitude
                updated.longitude = longitude
                onSaved(updated)
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Detaljvy

struct MeetupDetailView: View {
    @State private var meetup: Meetup
    var onChanged: () -> Void = {}

    init(meetup: Meetup, onChanged: @escaping () -> Void = {}) {
        _meetup = State(initialValue: meetup)
        self.onChanged = onChanged
    }

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var isWorking = false
    @State private var confirmDelete = false
    @State private var isPresentingEdit = false
    /// Stadsträff: är jag medlem i staden (och får därmed svara)?
    @State private var isCommunityMember = false
    @State private var confirmReport = false
    @State private var reportMessage: String?
    @State private var errorMessage: String?
    /// Teamuppgifter som är kopplade till den här träffen.
    @State private var linkedTasks: [TeamTask] = []

    private var myUid: String? { authService.currentUserID }
    private var isOwner: Bool { myUid == meetup.ownerUid }
    private var myRSVP: MeetupRSVP {
        guard let myUid else { return .pending }
        return meetup.rsvp(for: myUid)
    }

    /// Får jag svara på träffen? Inbjudna (team-/vänträff) eller medlemmar i
    /// stadsgruppen (stadsträff).
    private var canRSVP: Bool {
        guard let myUid, !isOwner else { return false }
        return meetup.invitedUids.contains(myUid) || isCommunityMember
    }

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = meetup.latitude, let lng = meetup.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private var goingNames: [String] {
        meetup.goingUids.compactMap { meetup.invitedNames[$0] }
    }
    private var declinedNames: [String] {
        meetup.declinedUids.compactMap { meetup.invitedNames[$0] }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header

                    if let coordinate {
                        mapCard(coordinate)
                    }

                    infoCard

                    if !linkedTasks.isEmpty {
                        linkedTasksCard
                    }

                    if canRSVP {
                        rsvpButtons
                    }

                    attendeesCard

                    if isOwner, !meetup.goingUids.isEmpty {
                        attendanceCard
                    }

                    if isOwner {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Ställ in träffen")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        // På knappen (inte vyn) så bekräftelsen dyker upp intill den.
                        .confirmationDialog(
                            "Ställ in träffen?",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible
                        ) {
                            Button("Ställ in", role: .destructive) { deleteMeetup() }
                            Button("Avbryt", role: .cancel) {}
                        }
                    } else if myUid != nil {
                        Button(role: .destructive) {
                            confirmReport = true
                        } label: {
                            Label("Rapportera träff", systemImage: "flag")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.Colors.textSecondary)
                        .confirmationDialog(
                            "Rapportera träffen?",
                            isPresented: $confirmReport,
                            titleVisibility: .visible
                        ) {
                            Button("Rapportera", role: .destructive) { report() }
                            Button("Avbryt", role: .cancel) {}
                        } message: {
                            Text("Träffen granskas av en moderator. Tack för att du hjälper till att hålla grupperna trygga.")
                        }
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.screenSurface)
            .navigationTitle("Träff")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                if isOwner {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Ändra") { isPresentingEdit = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingEdit) {
                EditMeetupView(meetup: meetup) { updated in
                    meetup = updated
                    onChanged()
                }
            }
            .alert(
                "Tack för din anmälan",
                isPresented: Binding(get: { reportMessage != nil }, set: { if !$0 { reportMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(reportMessage ?? "")
            }
            .alert(
                "Kunde inte spara",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadLinkedTasks() }
            .task { await loadMembership() }
            .task {
                // Hämta färskt läge vid öppning — RSVP-knappen får annars
                // gate:as av ett gammalt snapshot (t.ex. "fullbokat" som inte
                // stämmer, eller tvärtom).
                if let id = meetup.id, let fresh = await TeamsRepository.shared.meetup(id: id) {
                    meetup = fresh
                }
            }
        }
    }

    /// Stadsträff: kolla om jag är medlem i staden, så jag får svara.
    private func loadMembership() async {
        guard let uid = myUid, let communityId = meetup.communityId else { return }
        isCommunityMember = await CommunitiesRepository.shared.isMember(communityID: communityId, uid: uid)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(spacing: 0) {
                Text(meetup.date.formatted(.dateTime.day()))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.Colors.brand)
                Text(meetup.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(width: 56, height: 56)
            .background(Theme.Colors.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(meetup.title)
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("Ordnas av \(meetup.invitedNames[meetup.ownerUid] ?? meetup.ownerName)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func mapCard(_ coordinate: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))) {
            Marker(meetup.locationName, systemImage: "pawprint.fill", coordinate: coordinate)
                .tint(Theme.Colors.brand)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .allowsHitTesting(false)
        .id("\(coordinate.latitude),\(coordinate.longitude)")
        .overlay(alignment: .bottomTrailing) {
            Button {
                openInMaps(coordinate)
            } label: {
                Label("Öppna i Kartor", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }
            .padding(Theme.Spacing.s)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label {
                Text(meetup.locationName)
                    .foregroundStyle(Theme.Colors.textPrimary)
            } icon: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Theme.Colors.brand)
            }
            Label {
                Text(meetup.date.formatted(date: .complete, time: .shortened))
                    .foregroundStyle(Theme.Colors.textPrimary)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(Theme.Colors.brand)
            }
            if let teamName = meetup.teamName {
                Label {
                    Text(teamName)
                        .foregroundStyle(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(Theme.Colors.brand)
                }
            }
            if let seriesLabel = meetup.seriesLabel {
                Label {
                    Text(seriesLabel)
                        .foregroundStyle(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "repeat")
                        .foregroundStyle(Theme.Colors.brand)
                }
            }
            if let maxSpots = meetup.maxSpots {
                Label {
                    Text("\(meetup.goingUids.count) av \(maxSpots) platser tagna\(meetup.isFull ? " · Fullt" : "")")
                        .foregroundStyle(meetup.isFull ? Theme.Colors.warning : Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Theme.Colors.brand)
                }
            }
        }
        .font(Theme.Typography.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Uppgifter i teamet som är kopplade till träffen — det ni ska ha
    /// övat på tills ni ses.
    private var linkedTasksCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Uppgifter inför träffen")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            ForEach(linkedTasks) { task in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: task.isCompleted(by: myUid) ? "checkmark.circle.fill" : "checklist")
                        .foregroundStyle(task.isCompleted(by: myUid) ? .green : Theme.Colors.brand)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(task.title)
                            .font(Theme.Typography.body.weight(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Utlagd av \(task.createdByName) · \(task.completedUids.count) klara")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            Text("Bocka av dig under Uppgifter på teamsidan.")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Hämtar teamets uppgifter och plockar ut de som pekar på träffen.
    private func loadLinkedTasks() async {
        guard let teamId = meetup.teamId, let meetupId = meetup.id else { return }
        let all = await TeamsRepository.shared.tasks(teamID: teamId)
        linkedTasks = all.filter { $0.meetupId == meetupId }
    }

    private var rsvpButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                rsvp(going: true)
            } label: {
                Label(meetup.isFull && myRSVP != .going ? "Fullt" : "Kommer",
                      systemImage: myRSVP == .going ? "checkmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(myRSVP == .going ? .green : Theme.Colors.brand.opacity(0.4))
            .disabled(meetup.isFull && myRSVP != .going)

            Button {
                rsvp(going: false)
            } label: {
                Label("Kan inte", systemImage: myRSVP == .declined ? "xmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(myRSVP == .declined ? .red : Theme.Colors.textSecondary.opacity(0.3))
        }
        .disabled(isWorking)
    }

    private var attendeesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Kommer (\(goingNames.count))")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.brand)
            Text(goingNames.isEmpty ? "Ingen har svarat ja än." : goingNames.joined(separator: ", "))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textPrimary)

            if !declinedNames.isEmpty {
                Text("Kan inte (\(declinedNames.count))")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 2)
                Text(declinedNames.joined(separator: ", "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Närvaro: ägaren bockar av vilka som faktiskt var där — per tillfälle.
    private var attendanceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Närvaro")
                .font(Theme.Typography.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.brand)
            ForEach(meetup.goingUids, id: \.self) { uid in
                Button {
                    toggleAttendance(uid: uid)
                } label: {
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: meetup.didAttend(uid) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(meetup.didAttend(uid) ? .green : Theme.Colors.textSecondary)
                        Text(meetup.invitedNames[uid] ?? "Deltagare")
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("\((meetup.attendedUids ?? []).count) av \(meetup.goingUids.count) närvarade")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .disabled(isWorking)
    }

    private func toggleAttendance(uid: String) {
        guard let id = meetup.id else { return }
        let attended = !meetup.didAttend(uid)
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                // Skriv först — den lokala listan speglar bara det servern accepterat.
                try await TeamsRepository.shared.setAttendance(meetupID: id, uid: uid, attended: attended)
            } catch {
                errorMessage = String(localized: "Närvaron kunde inte sparas. Kontrollera din anslutning och försök igen.")
                return
            }
            var list = meetup.attendedUids ?? []
            list.removeAll { $0 == uid }
            if attended { list.append(uid) }
            meetup.attendedUids = list
            onChanged()
        }
    }

    private func rsvp(going: Bool) {
        guard let uid = myUid, let id = meetup.id else { return }
        let myName = currentUser.profile?.displayName ?? "Hundägare"
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                // Skriv först — annars visas "Kommer" lokalt utan att arrangören ser det.
                try await TeamsRepository.shared.setRSVP(meetupID: id, uid: uid, name: myName, going: going)
            } catch {
                errorMessage = String(localized: "Ditt svar kunde inte sparas. Kontrollera din anslutning och försök igen.")
                return
            }
            meetup.goingUids.removeAll { $0 == uid }
            meetup.declinedUids.removeAll { $0 == uid }
            if going {
                meetup.goingUids.append(uid)
            } else {
                meetup.declinedUids.append(uid)
            }
            // Så deltagarlistan visar mitt namn direkt, utan omladdning.
            meetup.invitedNames[uid] = myName
            onChanged()
        }
    }

    private func report() {
        guard let uid = myUid, let id = meetup.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "meetup",
                contentID: id,
                contentText: "\(meetup.title) · \(meetup.locationName)",
                authorUid: meetup.ownerUid,
                teamId: meetup.teamId,
                postID: id,
                postAuthorUid: meetup.ownerUid,
                reporterUid: uid
            )
            reportMessage = "Träffen är rapporterad och granskas."
        }
    }

    private func deleteMeetup() {
        guard let id = meetup.id else { return }
        Task {
            try? await TeamsRepository.shared.deleteMeetup(meetupID: id)
            onChanged()
            dismiss()
        }
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = meetup.locationName
        item.openInMaps()
    }
}
