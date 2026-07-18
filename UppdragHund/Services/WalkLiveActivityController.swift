//
//  WalkLiveActivityController.swift
//  UppdragHund
//
//  Startar/uppdaterar/avslutar promenadens Live Activity (låsskärm +
//  Dynamic Island). Uppdateringar trottlas — klockan tickar själv i
//  widgeten, så appen behöver bara pusha distans och pausläge.
//

import Foundation
import ActivityKit

@MainActor
final class WalkLiveActivityController {
    static let shared = WalkLiveActivityController()

    private var activity: Activity<WalkActivityAttributes>?
    private var lastPushedMeters: Double = 0
    private var lastPushDate: Date = .distantPast

    private init() {}

    func start(dogName: String, elapsedSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // Städa ev. kvarlämnad aktivitet (appen kraschade/avslutades).
        endAllStale()

        let state = WalkActivityAttributes.ContentState(
            distanceMeters: 0,
            elapsedSeconds: elapsedSeconds,
            isPaused: false,
            timerStart: Date.now.addingTimeInterval(-Double(elapsedSeconds))
        )
        activity = try? Activity.request(
            attributes: WalkActivityAttributes(dogName: dogName),
            content: .init(state: state, staleDate: nil)
        )
        lastPushedMeters = 0
        lastPushDate = .now
    }

    /// Anropas varje sekund från vyn — pushar bara när något faktiskt hänt:
    /// pausläge växlat, ≥10 m ny distans, eller ≥15 s sedan senaste push.
    func tick(distanceMeters: Double, elapsedSeconds: Int, isPaused: Bool) {
        guard let activity else { return }
        let pausedChanged = activity.content.state.isPaused != isPaused
        let movedEnough = abs(distanceMeters - lastPushedMeters) >= 10
        let timeForHeartbeat = Date.now.timeIntervalSince(lastPushDate) >= 15
        guard pausedChanged || movedEnough || timeForHeartbeat else { return }

        lastPushedMeters = distanceMeters
        lastPushDate = .now
        let state = WalkActivityAttributes.ContentState(
            distanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            isPaused: isPaused,
            timerStart: Date.now.addingTimeInterval(-Double(elapsedSeconds))
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end(distanceMeters: Double, elapsedSeconds: Int) {
        guard let activity else { return }
        self.activity = nil
        let finalState = WalkActivityAttributes.ContentState(
            distanceMeters: distanceMeters,
            elapsedSeconds: elapsedSeconds,
            isPaused: true,
            timerStart: .now
        )
        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    /// Avslutar alla aktiviteter av vår typ — försäkring mot spöken efter krasch.
    private func endAllStale() {
        for stale in Activity<WalkActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
