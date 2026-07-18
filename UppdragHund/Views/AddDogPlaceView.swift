//
//  AddDogPlaceView.swift
//  UppdragHund
//
//  Tipsa om ett hundvänligt ställe: namn, kategori, tips och plats
//  (nuvarande position som utgångspunkt, flyttbar genom att trycka på kartan).
//

import SwiftUI
import MapKit
import CoreLocation

struct AddDogPlaceView: View {
    /// Startposition — användarens nuvarande plats om känd.
    let initialCoordinate: CLLocationCoordinate2D?
    var onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var name = ""
    @State private var category: DogPlaceCategory = .cafe
    @State private var tip = ""
    @State private var coordinate: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(initialCoordinate: CLLocationCoordinate2D?, onAdded: @escaping () -> Void) {
        self.initialCoordinate = initialCoordinate
        self.onAdded = onAdded
        let start = initialCoordinate ?? CLLocationCoordinate2D(latitude: 59.33, longitude: 18.06)
        _coordinate = State(initialValue: start)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: start, latitudinalMeters: 1500, longitudinalMeters: 1500
        )))
    }

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Namn på stället", text: $name)
                    Picker("Kategori", selection: $category) {
                        ForEach(DogPlaceCategory.allCases) { c in
                            Label(c.title, systemImage: c.icon).tag(c)
                        }
                    }
                }
                Section {
                    TextField("Tips (valfritt) — t.ex. vattenskål ute, hundgodis i disken", text: $tip, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    MapReader { proxy in
                        Map(position: $cameraPosition) {
                            Marker(name.isEmpty ? String(localized: "Här") : name, systemImage: category.icon, coordinate: coordinate)
                                .tint(Theme.Colors.brand)
                        }
                        .frame(height: 220)
                        .onTapGesture { screenPoint in
                            if let tapped = proxy.convert(screenPoint, from: .local) {
                                coordinate = tapped
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Plats")
                } footer: {
                    Text("Tryck på kartan för att flytta nålen till rätt ställe.")
                }

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle("Tipsa om ställe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }.disabled(!isValid || isSaving)
                }
            }
        }
    }

    private func save() {
        guard let uid = authService.currentUserID else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            let place = DogPlace(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category.rawValue,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                address: nil,
                tip: tip.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                createdByUid: uid,
                createdByName: currentUser.profile?.displayName ?? String(localized: "Hundägare"),
                createdAt: .now,
                recommendedBy: []
            )
            do {
                try await DogPlacesRepository.shared.add(place)
                onAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
