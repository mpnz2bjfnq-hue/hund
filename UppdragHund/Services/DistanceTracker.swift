//
//  DistanceTracker.swift
//  UppdragHund
//
//  Mäter tillryggalagd sträcka via sensorfusion: GPS ger positionen,
//  stegräknaren (CoreMotion) avgör OM man faktiskt rör sig. GPS-drift
//  uppstår när man står still — och då säger stegräknaren stopp.
//

import Foundation
import CoreLocation
import CoreMotion

@Observable
final class DistanceTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let pedometer = CMPedometer()
    private var lastLocation: CLLocation?

    var meters: Double = 0
    var isTracking = false
    var permissionDenied = false
    /// Godkända GPS-punkter i ordning — ritas som rutt på kartan.
    var route: [CLLocationCoordinate2D] = []
    /// Senaste GPS-noggrannheten i meter — för signalindikatorn i UI:t.
    var currentAccuracy: Double?
    /// Stegräknarens antal steg sedan start — visas i UI:t.
    var stepCount: Int = 0

    // Tidsmätning: datumbaserad, INTE tick-baserad — en sekundtimer i vyn
    // stannar när appen suspenderas och tappar då hela bakgrundstiden.
    private var activeSince: Date?
    private var accumulatedSeconds: TimeInterval = 0

    /// Total aktiv promenadtid i sekunder (pauser exkluderade). Korrekt även
    /// efter att appen legat i bakgrunden eller skärmen varit låst.
    var elapsedSeconds: Int {
        Int(accumulatedSeconds + (activeSince.map { Date.now.timeIntervalSince($0) } ?? 0))
    }

    // Stegräknar-gaten: GPS-steg räknas bara när steg nyligen registrerats.
    private var lastStepCount = 0
    private var lastStepIncreaseAt = Date.distantPast
    /// När spårningen (åter)startades — varmkörningsfönster för stegdata.
    private var resumedAt = Date.distantPast

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5
    }

    private var hasStarted = false

    func start() {
        if !hasStarted {
            meters = 0
            route = []
            stepCount = 0
            accumulatedSeconds = 0
            hasStarted = true
        }
        // Nollställ referenspunkten så en paus inte räknas som förflyttning.
        lastLocation = nil
        isTracking = true
        resumedAt = .now
        activeSince = .now
        manager.requestWhenInUseAuthorization()
        // Fortsätt mäta med skärmen låst — kräver UIBackgroundModes: location.
        // Bara under aktiv spårning; blå statusindikatorn visar ärligt att
        // positionen används.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
        startPedometer()
    }

    func stop() {
        if let activeSince {
            accumulatedSeconds += Date.now.timeIntervalSince(activeSince)
        }
        activeSince = nil
        isTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        pedometer.stopUpdates()
    }

    func reset() {
        meters = 0
        route = []
        stepCount = 0
        lastLocation = nil
        hasStarted = false
        lastStepCount = 0
        lastStepIncreaseAt = .distantPast
        resumedAt = .distantPast
        activeSince = nil
        accumulatedSeconds = 0
    }

    // MARK: - Stegräknare (rörelse-gate)

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable(),
              CMPedometer.authorizationStatus() != .denied else { return }
        let priorSteps = lastStepCount
        pedometer.startUpdates(from: .now) { [weak self] data, _ in
            guard let self, let data else { return }
            DispatchQueue.main.async {
                let steps = priorSteps + data.numberOfSteps.intValue
                if steps > self.lastStepCount {
                    self.lastStepCount = steps
                    self.lastStepIncreaseAt = .now
                }
                self.stepCount = steps
            }
        }
    }

    /// Rör sig användaren enligt stegräknaren?
    /// OBS: stegräknaren är TYST när man står still (callbacken triggas bara
    /// av steg) — därför är gaten STÄNGD som standard när stegdata kan
    /// förväntas. Öppen bara utan behörighet/hårdvara (då gäller GPS-filtren).
    /// Kan stegräknaren agera rörelse-gate? (Hårdvara + behörighet.)
    private var pedometerGateAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
            && CMPedometer.authorizationStatus() == .authorized
    }

    private var isProbablyMoving: Bool {
        guard pedometerGateAvailable else { return true }
        // Steg nyligen → vi går.
        if Date.now.timeIntervalSince(lastStepIncreaseAt) < 12 { return true }
        // Varmkörning: ge stegräknaren några sekunder efter start/fortsätt
        // innan tystnad tolkas som stillastående.
        return Date.now.timeIntervalSince(resumedAt) < 8
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            // Färska punkter med rimlig noggrannhet — cachade/suddiga slängs.
            guard location.timestamp.timeIntervalSinceNow > -5 else { continue }
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 20 else {
                currentAccuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
                continue
            }
            currentAccuracy = location.horizontalAccuracy

            guard let last = lastLocation else {
                lastLocation = location
                route.append(location.coordinate)
                continue
            }

            let step = location.distance(from: last)

            // Stegräknar-gaten: registreras inga steg rör vi oss inte, och
            // då är ALL GPS-rörelse drift. Referensen följer med så att
            // uppsamlad drift inte räknas när man börjar gå igen.
            guard isProbablyMoving else {
                lastLocation = location
                continue
            }

            // När stegräknaren bekräftar rörelse är GPS-stegen riktiga —
            // då räcker ett milt brusfilter. (Den hårda osäkerhetströskeln
            // behövs bara utan stegdata, där gaten inte kan skydda.)
            let minimumStep = pedometerGateAvailable
                ? max(3, location.horizontalAccuracy * 0.3)
                : max(5, location.horizontalAccuracy)
            guard step >= minimumStep else { continue }

            // Teleporteringar (tunnlar, cellbyten): orimlig fart → flytta
            // referensen utan att räkna sträckan.
            let dt = location.timestamp.timeIntervalSince(last.timestamp)
            if dt > 0, step / dt > 10 {
                lastLocation = location
                continue
            }

            meters += step
            lastLocation = location
            route.append(location.coordinate)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            permissionDenied = true
        default:
            permissionDenied = false
        }
    }
}
