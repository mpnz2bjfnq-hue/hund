//
//  NearbyPlacesView.swift
//  UppdragHund
//
//  Hundvänliga platser i närheten via MapKit (MKLocalSearch) — ingen
//  API-nyckel eller backend behövs. Söker per kategori runt användaren
//  och visar resultat på karta + lista, tap öppnar i Apple Kartor.
//

import SwiftUI
import MapKit
import CoreLocation

struct NearbyPlacesView: View {
    private enum Category: String, CaseIterable, Identifiable {
        case vet, dogPark, petStore, cafe

        var id: String { rawValue }

        var title: String {
            switch self {
            case .vet: String(localized: "Veterinär")
            case .dogPark: String(localized: "Rastgård")
            case .petStore: String(localized: "Djuraffär")
            case .cafe: String(localized: "Hundvänligt café")
            }
        }

        /// Naturligt sökord till MKLocalSearch.
        var query: String {
            switch self {
            case .vet: "veterinär"
            case .dogPark: "hundrastgård"
            case .petStore: "djuraffär"
            case .cafe: "hundvänligt café"
            }
        }

        var icon: String {
            switch self {
            case .vet: "cross.case.fill"
            case .dogPark: "tree.fill"
            case .petStore: "bag.fill"
            case .cafe: "cup.and.saucer.fill"
            }
        }

        var tint: Color {
            switch self {
            case .vet: .red
            case .dogPark: Theme.Colors.brand
            case .petStore: .blue
            case .cafe: .orange
            }
        }
    }

    @State private var locationProvider = OneShotLocation()
    @State private var category: Category = .dogPark
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 0) {
            Picker("Kategori", selection: $category) {
                ForEach(Category.allCases) { c in
                    Text(c.title).tag(c)
                }
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.m)

            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(results, id: \.self) { item in
                    if let coord = item.placemark.location?.coordinate {
                        Marker(item.name ?? category.title, systemImage: category.icon, coordinate: coord)
                            .tint(category.tint)
                    }
                }
            }
            .frame(height: 260)
            .overlay(alignment: .center) {
                if isSearching { ProgressView().padding().background(.thinMaterial, in: Capsule()) }
            }

            if results.isEmpty && !isSearching {
                ContentUnavailableView(
                    "Inga platser hittades",
                    systemImage: "mappin.slash",
                    description: Text("Prova en annan kategori, eller flytta dig till ett område med fler platser.")
                )
            } else {
                List(results, id: \.self) { item in
                    Button {
                        item.openInMaps()
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? category.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                if let subtitle = addressLine(item) {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            if let distance = distanceText(item) {
                                Text(distance)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Nära dig")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.screenSurface)
        .task { await locationProvider.request() }
        .task(id: category) { await search() }
        .onChange(of: locationProvider.location) { _, _ in Task { await search() } }
    }

    private func search() async {
        guard let location = locationProvider.location else { return }
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category.query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 15_000,
            longitudinalMeters: 15_000
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            let sorted = response.mapItems.sorted { a, b in
                (a.placemark.location?.distance(from: location) ?? .greatestFiniteMagnitude)
                    < (b.placemark.location?.distance(from: location) ?? .greatestFiniteMagnitude)
            }
            results = sorted
            cameraPosition = .region(MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            ))
        } catch {
            results = []
        }
    }

    private func addressLine(_ item: MKMapItem) -> String? {
        let p = item.placemark
        return [p.thoroughfare, p.locality].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
    }

    private func distanceText(_ item: MKMapItem) -> String? {
        guard let here = locationProvider.location,
              let there = item.placemark.location else { return nil }
        let meters = there.distance(from: here)
        return meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters)) m"
    }
}

/// Enkel engångshämtare av användarens position — räcker för platssök.
@Observable
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() async {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last { location = latest }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
