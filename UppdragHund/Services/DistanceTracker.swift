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

    // Stegräknar-gaten: GPS-steg räknas bara när steg nyligen registrerats.
    private var pedometerHasData = false
    private var lastStepCount = 0
    private var lastStepIncreaseAt = Date.distantPast

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
            hasStarted = true
        }
        // Nollställ referenspunkten så en paus inte räknas som förflyttning.
        lastLocation = nil
        isTracking = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        startPedometer()
    }

    func stop() {
        isTracking = false
        manager.stopUpdatingLocation()
        pedometer.stopUpdates()
    }

    func reset() {
        meters = 0
        route = []
        stepCount = 0
        lastLocation = nil
        hasStarted = false
        pedometerHasData = false
        lastStepCount = 0
        lastStepIncreaseAt = .distantPast
    }

    // MARK: - Stegräknare (rörelse-gate)

    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable(),
              CMPedometer.authorizationStatus() != .denied else { return }
        let priorSteps = lastStepCount
        pedometer.startUpdates(from: .now) { [weak self] data, _ in
            guard let self, let data else { return }
            DispatchQueue.main.async {
                self.pedometerHasData = true
                let steps = priorSteps + data.numberOfSteps.intValue
                if steps > self.lastStepCount {
                    self.lastStepCount = steps
                    self.lastStepIncreaseAt = .now
                }
                self.stepCount = steps
            }
        }
    }

    /// Rör sig användaren enligt stegräknaren? Utan stegdata (nekad
    /// behörighet, äldre enhet) faller vi tillbaka på enbart GPS-filtren.
    private var isProbablyMoving: Bool {
        guard pedometerHasData else { return true }
        return Date.now.timeIntervalSince(lastStepIncreaseAt) < 12
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
                // Första referenspunkten kräver skarp fix — annars startar
                // rutten i en dålig gissning och "vandrar" därifrån.
                if location.horizontalAccuracy <= 15 {
                    lastLocation = location
                    route.append(location.coordinate)
                }
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

            // Stillastående-drift: GPS:en vandrar slumpmässigt inom sin
            // osäkerhetsradie. Steg mindre än osäkerheten är brus, inte rörelse.
            let minimumStep = max(5, location.horizontalAccuracy)
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
