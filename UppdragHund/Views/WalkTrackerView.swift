//
//  WalkTrackerView.swift
//  UppdragHund
//
//  Logga en promenad med GPS: räknar sträcka och tid live, sparar som en
//  träningssession.
//

import SwiftUI
import SwiftData
import Combine
import MapKit

struct WalkTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let dog: Dog
    /// Startar spårningen direkt när vyn visas — för widget/kontroll-flödet
    /// där användaren redan tryckt "starta" på låsskärmen.
    var autoStart = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var tracker = DistanceTracker()
    @State private var elapsed = 0
    @State private var started = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// GPS-signal i tre lägen utifrån senaste noggrannheten.
    private var gpsSignal: (label: String, color: Color) {
        guard let accuracy = tracker.currentAccuracy else {
            return (String(localized: "SÖKER GPS"), .orange)
        }
        if accuracy <= 10 { return (String(localized: "GPS BRA"), Theme.Colors.brand) }
        if accuracy <= 20 { return (String(localized: "GPS OK"), .yellow) }
        return (String(localized: "GPS SVAG"), .orange)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.l) {
                Map(position: .constant(.userLocation(fallback: .automatic))) {
                    UserAnnotation()
                    if tracker.route.count > 1 {
                        MapPolyline(coordinates: tracker.route)
                            .stroke(Theme.Colors.brand, lineWidth: 5)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
                .overlay(alignment: .topTrailing) {
                    // GPS-signalindikator à la sportklockor.
                    HStack(spacing: 5) {
                        Circle()
                            .fill(gpsSignal.color)
                            .frame(width: 7, height: 7)
                        Text(gpsSignal.label)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(Theme.Spacing.m)
                }
                .padding(.horizontal)

                // Mätarpanel: distans stort i mitten, tid och tempo flankerar.
                VStack(spacing: Theme.Spacing.s) {
                    Text("DISTANS")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(WalkFormatting.distance(tracker.meters))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.Colors.brand)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.4), value: tracker.meters)
                        Text(WalkFormatting.distanceUnit(tracker.meters))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    HStack {
                        walkMetric(
                            label: String(localized: "TID"),
                            value: WalkFormatting.elapsed(elapsed)
                        )
                        Rectangle()
                            .fill(Theme.Colors.textSecondary.opacity(0.2))
                            .frame(width: 1, height: 34)
                        walkMetric(
                            label: String(localized: "TEMPO"),
                            value: WalkFormatting.pace(
                                secondsPerKm: WalkFormatting.paceSecondsPerKm(meters: tracker.meters, elapsedSeconds: elapsed)
                            ),
                            unit: "/km"
                        )
                        Rectangle()
                            .fill(Theme.Colors.textSecondary.opacity(0.2))
                            .frame(width: 1, height: 34)
                        walkMetric(
                            label: String(localized: "STEG"),
                            value: "\(tracker.stepCount)"
                        )
                    }
                    .padding(.top, Theme.Spacing.s)
                }
                .frame(maxWidth: .infinity)
                .cardStyle(padding: Theme.Spacing.l)
                .padding(.horizontal)

                if tracker.permissionDenied {
                    Text("Platsåtkomst nekad. Slå på under Inställningar → Canine360 → Plats.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()

                // Stor rund start/paus — sportklocke-känslan.
                Button {
                    toggleTracking()
                } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Theme.Colors.brand, Theme.Colors.brand.opacity(0.75)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 78, height: 78)
                            .shadow(color: Theme.Colors.brand.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 14, y: 5)
                        Image(systemName: tracker.isTracking ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(CardPressStyle())
                .accessibilityLabel(tracker.isTracking ? "Pausa" : (started ? "Fortsätt" : "Starta promenad"))

                Text(tracker.isTracking ? "Pausa" : (started ? "Fortsätt" : "Starta promenad"))
                    .font(Theme.Typography.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.bottom)
            .background(Theme.screenSurface)
            .navigationTitle("Promenad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { tracker.stop(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Spara") { save() }.disabled(!started) }
            }
            .onReceive(timer) { _ in
                // Timern driver bara OMRITNINGEN — tiden ägs av trackern
                // (datumbaserad), så bakgrundstid inte tappas när timern sover.
                elapsed = tracker.elapsedSeconds
                if tracker.isTracking {
                    WalkLiveActivityController.shared.tick(
                        distanceMeters: tracker.meters, elapsedSeconds: elapsed, isPaused: false
                    )
                }
            }
            .onDisappear {
                tracker.stop()
                WalkLiveActivityController.shared.end(distanceMeters: tracker.meters, elapsedSeconds: tracker.elapsedSeconds)
            }
            .task {
                // Från widget/kontroll: användaren har redan tryckt "starta".
                if autoStart && !started {
                    toggleTracking()
                }
            }
        }
    }

    private func toggleTracking() {
        if tracker.isTracking {
            tracker.stop()
            elapsed = tracker.elapsedSeconds
            WalkLiveActivityController.shared.tick(
                distanceMeters: tracker.meters, elapsedSeconds: elapsed, isPaused: true
            )
        } else {
            let isFirstStart = !started
            tracker.start()
            started = true
            elapsed = tracker.elapsedSeconds
            if isFirstStart {
                WalkLiveActivityController.shared.start(dogName: dog.name, elapsedSeconds: elapsed)
            } else {
                WalkLiveActivityController.shared.tick(
                    distanceMeters: tracker.meters, elapsedSeconds: elapsed, isPaused: false
                )
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func walkMetric(label: String, value: String, unit: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.Colors.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        tracker.stop()
        guard DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID).canLog(in: .training) else {
            dismiss()
            return
        }
        let minutes = max(1, Int((Double(tracker.elapsedSeconds) / 60).rounded()))
        let session = TrainingSession(
            date: .now,
            activity: "Promenad",
            durationMinutes: minutes,
            distanceMeters: tracker.meters > 0 ? tracker.meters : nil,
            dog: dog
        )
        session.routeData = TrainingSession.encodeRoute(
            tracker.route.map { (latitude: $0.latitude, longitude: $0.longitude) }
        )
        session.steps = tracker.stepCount > 0 ? tracker.stepCount : nil
        modelContext.insert(session)
        SyncCoordinator.shared.entryTouched(session, dog: dog)
        dismiss()
    }
}

// MARK: - Visa sparad rutt

struct RouteMapView: View {
    let session: TrainingSession

    @Environment(\.dismiss) private var dismiss

    private var coordinates: [CLLocationCoordinate2D] {
        session.routeCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        NavigationStack {
            Map(initialPosition: mapPosition) {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(Theme.Colors.brand, lineWidth: 5)
                }
                if let first = coordinates.first {
                    Annotation("Start", coordinate: first) {
                        Image(systemName: "flag.fill").foregroundStyle(.green)
                    }
                }
                if let last = coordinates.last, coordinates.count > 1 {
                    Annotation("Mål", coordinate: last) {
                        Image(systemName: "flag.checkered").foregroundStyle(Theme.Colors.textPrimary)
                    }
                }
            }
            .navigationTitle([session.distanceText, session.durationMinutes.map { "\($0) min" }]
                .compactMap { $0 }
                .joined(separator: " · "))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Klar") { dismiss() } }
            }
        }
    }

    private var mapPosition: MapCameraPosition {
        guard !coordinates.isEmpty else { return .automatic }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.003, (lats.max()! - lats.min()!) * 1.4),
            longitudeDelta: max(0.003, (lons.max()! - lons.min()!) * 1.4)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }
}
