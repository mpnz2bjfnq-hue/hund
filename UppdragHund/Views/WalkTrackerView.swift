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
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var tracker = DistanceTracker()
    @State private var elapsed = 0
    @State private var started = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var distanceText: String {
        if tracker.meters >= 1000 {
            return String(format: "%.2f km", tracker.meters / 1000)
        }
        return "\(Int(tracker.meters)) m"
    }

    private var timeText: String {
        String(format: "%d:%02d", elapsed / 60, elapsed % 60)
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
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(distanceText)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(timeText)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if tracker.permissionDenied {
                    Text("Platsåtkomst nekad. Slå på under Inställningar → Canine360 → Plats.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
                Button {
                    if tracker.isTracking {
                        tracker.stop()
                        WalkLiveActivityController.shared.tick(
                            distanceMeters: tracker.meters, elapsedSeconds: elapsed, isPaused: true
                        )
                    } else {
                        let isFirstStart = !started
                        tracker.start()
                        started = true
                        if isFirstStart {
                            WalkLiveActivityController.shared.start(dogName: dog.name, elapsedSeconds: elapsed)
                        } else {
                            WalkLiveActivityController.shared.tick(
                                distanceMeters: tracker.meters, elapsedSeconds: elapsed, isPaused: false
                            )
                        }
                    }
                } label: {
                    Label(
                        tracker.isTracking ? "Pausa" : (started ? "Fortsätt" : "Starta promenad"),
                        systemImage: tracker.isTracking ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.Colors.brand)
                .padding(.horizontal)
            }
            .padding(.bottom)
            .navigationTitle("Promenad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { tracker.stop(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Spara") { save() }.disabled(!started) }
            }
            .onReceive(timer) { _ in
                if tracker.isTracking {
                    elapsed += 1
                    WalkLiveActivityController.shared.tick(
                        distanceMeters: tracker.meters, elapsedSeconds: elapsed, isPaused: false
                    )
                }
            }
            .onDisappear {
                tracker.stop()
                WalkLiveActivityController.shared.end(distanceMeters: tracker.meters, elapsedSeconds: elapsed)
            }
        }
    }

    private func save() {
        tracker.stop()
        guard DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID).canLog(in: .training) else {
            dismiss()
            return
        }
        let minutes = max(1, Int((Double(elapsed) / 60).rounded()))
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
