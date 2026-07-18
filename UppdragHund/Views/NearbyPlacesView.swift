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
    // Bara kategorier som Apple Kartor har pålitlig data för. "Hundvänligt
    // café" fanns tidigare men togs bort — MKLocalSearch kan inte verifiera
    // hundvänlighet, så etiketten lovade mer än den kunde hålla.
    private enum Category: String, CaseIterable, Identifiable {
        case tips, vet, dogPark, petStore

        var id: String { rawValue }

        /// Community-läget skiljer sig helt — våra egna tips i stället för
        /// Apples kartdata.
        var isCommunity: Bool { self == .tips }

        var title: String {
            switch self {
            case .tips: String(localized: "Tips 🐾")
            case .vet: String(localized: "Veterinär")
            case .dogPark: String(localized: "Rastgård")
            case .petStore: String(localized: "Djuraffär")
            }
        }

        /// Naturligt sökord till MKLocalSearch (ej relevant för tips).
        var query: String {
            switch self {
            case .tips: ""
            case .vet: "veterinär"
            case .dogPark: "hundrastgård"
            case .petStore: "djuraffär"
            }
        }

        var icon: String {
            switch self {
            case .tips: "pawprint.fill"
            case .vet: "cross.case.fill"
            case .dogPark: "tree.fill"
            case .petStore: "bag.fill"
            }
        }

        var tint: Color {
            switch self {
            case .tips: Theme.Colors.brand
            case .vet: .red
            case .dogPark: Theme.Colors.brand
            case .petStore: .blue
            }
        }
    }

    @State private var locationProvider = OneShotLocation()
    @State private var authService = AuthService.shared
    @State private var category: Category = .tips
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Community-tips
    @State private var places: [DogPlace] = []
    @State private var isAddingPlace = false
    @State private var placePendingDelete: DogPlace?
    @State private var reportMessage: String?

    private var sortedPlaces: [DogPlace] {
        guard let here = locationProvider.location else { return places }
        return places.sorted {
            distance(to: $0, from: here) < distance(to: $1, from: here)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Kategori", selection: $category) {
                ForEach(Category.allCases) { c in
                    Text(c.title).tag(c)
                }
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.m)

            if category.isCommunity {
                communityContent
            } else {
                mapKitContent
            }
        }
        .navigationTitle("Nära dig")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.screenSurface)
        .toolbar {
            if category.isCommunity {
                ToolbarItem(placement: .primaryAction) {
                    Button { isAddingPlace = true } label: { Label("Tipsa om ställe", systemImage: "plus") }
                }
            }
        }
        .sheet(isPresented: $isAddingPlace) {
            AddDogPlaceView(initialCoordinate: locationProvider.location?.coordinate) {
                Task { await loadPlaces() }
            }
        }
        .alert("Tack för din anmälan", isPresented: Binding(
            get: { reportMessage != nil }, set: { if !$0 { reportMessage = nil } }
        )) { Button("OK") {} } message: { Text(reportMessage ?? "") }
        .task { await locationProvider.request() }
        .task { await loadPlaces() }
        .task(id: category) { if !category.isCommunity { await search() } }
        .onChange(of: locationProvider.location) { _, _ in
            if !category.isCommunity { Task { await search() } }
        }
    }

    // MARK: - Community-tips

    @ViewBuilder
    private var communityContent: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(places) { place in
                Marker(place.name, systemImage: place.resolvedCategory.icon,
                       coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                    .tint(Theme.Colors.brand)
            }
        }
        .frame(height: 260)

        if places.isEmpty {
            ContentUnavailableView(
                "Inga tips än",
                systemImage: "pawprint",
                description: Text("Känner du till ett hundvänligt ställe? Tryck på + och dela det med andra hundägare.")
            )
        } else {
            List(sortedPlaces) { place in
                placeRow(place)
            }
        }
    }

    private func placeRow(_ place: DogPlace) -> some View {
        let uid = authService.currentUserID
        let recommended = place.isRecommended(by: uid)
        return HStack(spacing: Theme.Spacing.m) {
            Image(systemName: place.resolvedCategory.icon)
                .foregroundStyle(Theme.Colors.brand)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text([place.resolvedCategory.title, place.tip].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let d = placeDistanceText(place) {
                Text(d).font(.caption2).foregroundStyle(Theme.Colors.textSecondary)
            }
            Button {
                toggleRecommend(place)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: recommended ? "pawprint.fill" : "pawprint")
                    Text("\(place.recommendedBy.count)")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(recommended ? Theme.Colors.brand : Theme.Colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { openInMaps(place) }
        .contextMenu {
            Button { openInMaps(place) } label: { Label("Öppna i Kartor", systemImage: "map") }
            if place.createdByUid == uid {
                Button(role: .destructive) { placePendingDelete = place } label: {
                    Label("Ta bort", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) { report(place) } label: {
                    Label("Rapportera", systemImage: "flag")
                }
            }
        }
        .confirmationDialog(
            "Ta bort ditt tips?",
            isPresented: Binding(
                get: { placePendingDelete?.id == place.id },
                set: { if !$0 { placePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                delete(place); placePendingDelete = nil
            }
            Button("Avbryt", role: .cancel) { placePendingDelete = nil }
        }
    }

    // MARK: - MapKit-kategorier

    @ViewBuilder
    private var mapKitContent: some View {
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

    // MARK: - Community-data

    private func loadPlaces() async {
        places = (try? await DogPlacesRepository.shared.all()) ?? places
    }

    private func toggleRecommend(_ place: DogPlace) {
        guard let uid = authService.currentUserID, let id = place.id else { return }
        let recommend = !place.isRecommended(by: uid)
        // Optimistisk uppdatering.
        if let idx = places.firstIndex(where: { $0.id == id }) {
            if recommend { places[idx].recommendedBy.append(uid) }
            else { places[idx].recommendedBy.removeAll { $0 == uid } }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { try? await DogPlacesRepository.shared.toggleRecommend(placeID: id, uid: uid, recommend: recommend) }
    }

    private func delete(_ place: DogPlace) {
        guard let id = place.id else { return }
        places.removeAll { $0.id == id }
        Task { try? await DogPlacesRepository.shared.delete(placeID: id) }
    }

    private func report(_ place: DogPlace) {
        guard let uid = authService.currentUserID, let id = place.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "dogPlace", contentID: id,
                contentText: "\(place.name) — \(place.tip ?? "")",
                authorUid: place.createdByUid, teamId: nil,
                postID: id, postAuthorUid: place.createdByUid, reporterUid: uid
            )
            reportMessage = String(localized: "Stället granskas av en moderator. Tack för att du hjälper till.")
        }
    }

    private func openInMaps(_ place: DogPlace) {
        let coord = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = place.name
        item.openInMaps()
    }

    private func distance(to place: DogPlace, from here: CLLocation) -> Double {
        CLLocation(latitude: place.latitude, longitude: place.longitude).distance(from: here)
    }

    private func placeDistanceText(_ place: DogPlace) -> String? {
        guard let here = locationProvider.location else { return nil }
        let meters = distance(to: place, from: here)
        return meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters)) m"
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
