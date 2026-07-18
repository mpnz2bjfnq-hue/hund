//
//  DogPlace.swift
//  UppdragHund
//
//  Community-tipsade hundvänliga ställen. Lagras i Firestore (delas av alla
//  inloggade), till skillnad från MapKit-sökningarna som bara är Apples data.
//

import Foundation
import FirebaseFirestore

enum DogPlaceCategory: String, Codable, CaseIterable, Identifiable {
    case cafe, restaurant, shop, park, beach, hotel, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cafe: String(localized: "Café")
        case .restaurant: String(localized: "Restaurang")
        case .shop: String(localized: "Butik")
        case .park: String(localized: "Park")
        case .beach: String(localized: "Badplats")
        case .hotel: String(localized: "Hotell")
        case .other: String(localized: "Övrigt")
        }
    }

    var icon: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .restaurant: "fork.knife"
        case .shop: "bag.fill"
        case .park: "tree.fill"
        case .beach: "beach.umbrella.fill"
        case .hotel: "bed.double.fill"
        case .other: "mappin.circle.fill"
        }
    }
}

struct DogPlace: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var name: String
    var category: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var tip: String?
    var createdByUid: String
    var createdByName: String
    var createdAt: Date
    /// uid → togglas när någon rekommenderar. Antalet = tass-betyget.
    var recommendedBy: [String]

    var resolvedCategory: DogPlaceCategory {
        DogPlaceCategory(rawValue: category) ?? .other
    }

    func isRecommended(by uid: String?) -> Bool {
        guard let uid else { return false }
        return recommendedBy.contains(uid)
    }
}
