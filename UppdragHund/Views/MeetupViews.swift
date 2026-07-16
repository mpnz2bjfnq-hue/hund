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
                    HStack(spacing: Theme.Spacing.s) {
                        Text("\(meetup.goingUids.count) kommer")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.brand)
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
    @State private var isWorking = false
    @State private var confirmDelete = false

    private var myUid: String? { authService.currentUserID }
    private var isOwner: Bool { myUid == meetup.ownerUid }
    private var myRSVP: MeetupRSVP {
        guard let myUid else { return .pending }
        return meetup.rsvp(for: myUid)
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

                    if !isOwner, let myUid, meetup.invitedUids.contains(myUid) {
                        rsvpButtons
                    }

                    attendeesCard

                    if isOwner {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Ställ in träffen")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Träff")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
            .confirmationDialog(
                "Ställ in träffen?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Ställ in", role: .destructive) { deleteMeetup() }
                Button("Avbryt", role: .cancel) {}
            }
        }
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
        }
        .font(Theme.Typography.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var rsvpButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                rsvp(going: true)
            } label: {
                Label("Kommer", systemImage: myRSVP == .going ? "checkmark.circle.fill" : "circle")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(myRSVP == .going ? .green : Theme.Colors.brand.opacity(0.4))

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

    private func rsvp(going: Bool) {
        guard let uid = myUid, let id = meetup.id else { return }
        isWorking = true
        Task {
            try? await TeamsRepository.shared.setRSVP(meetupID: id, uid: uid, going: going)
            meetup.goingUids.removeAll { $0 == uid }
            meetup.declinedUids.removeAll { $0 == uid }
            if going {
                meetup.goingUids.append(uid)
            } else {
                meetup.declinedUids.append(uid)
            }
            isWorking = false
            onChanged()
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
