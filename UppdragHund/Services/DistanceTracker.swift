//
//  DistanceTracker.swift
//  UppdragHund
//
//  Mäter tillryggalagd sträcka i meter via GPS. Används när en övning har
//  ett meter-mål (t.ex. "spring 100 m").
//

import Foundation
import CoreLocation

@Observable
final class DistanceTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    var meters: Double = 0
    var isTracking = false
    var permissionDenied = false
    /// Godkända GPS-punkter i ordning — ritas som rutt på kartan.
    var route: [CLLocationCoordinate2D] = []
    /// Senaste GPS-noggrannheten i meter — för signalindikatorn i UI:t.
    var currentAccuracy: Double?

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
            hasStarted = true
        }
        // Nollställ referenspunkten så en paus inte räknas som förflyttning.
        lastLocation = nil
        isTracking = true
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        isTracking = false
        manager.stopUpdatingLocation()
    }

    func reset() {
        meters = 0
        route = []
        lastLocation = nil
        hasStarted = false
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
