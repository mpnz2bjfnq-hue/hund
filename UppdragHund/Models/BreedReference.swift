//
//  BreedReference.swift
//  UppdragHund
//

import Foundation

enum BreedSizeCategory: String, Codable {
    case small
    case medium
    case large
    case giant
    case unknown
}

struct BreedReference: Codable, Equatable {
    let breedName: String
    let sizeCategory: BreedSizeCategory
    let averageCycleIntervalDays: Int
    let averageCycleDurationDays: Int
}

extension BreedReference {
    static let genericFallback = BreedReference(
        breedName: "Okänd ras",
        sizeCategory: .unknown,
        averageCycleIntervalDays: 195,
        averageCycleDurationDays: 19
    )
}

enum BreedReferenceMatcher {
    static func reference(forBreed breedName: String, in references: [BreedReference]) -> BreedReference {
        let normalized = breedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return .genericFallback }
        return references.first { $0.breedName.lowercased() == normalized } ?? .genericFallback
    }
}
