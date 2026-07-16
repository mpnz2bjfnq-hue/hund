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

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 3
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
            // Släng ifrån GPS-brus: bara rimligt noggranna punkter räknas.
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 25 else { continue }
            if let last = lastLocation {
                let step = location.distance(from: last)
                // Ignorera små hopp (< 1 m) för att inte räcka upp meter när man står still.
                if step >= 1 {
                    meters += step
                    lastLocation = location
                    route.append(location.coordinate)
                }
            } else {
                lastLocation = location
                route.append(location.coordinate)
            }
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
