//
//  BreedDataService.swift
//  UppdragHund
//

import Foundation

@Observable
final class BreedDataService {
    static let shared = BreedDataService()

    /// Placeholder — pekar inte på något hostat innehåll än. Fjärruppdatering
    /// misslyckas därför tyst och appen fortsätter använda buntad/cachead data
    /// tills en riktig URL sätts upp.
    private let remoteURL = URL(string: "https://example.com/uppdraghund/breed-references.json")!

    private(set) var references: [BreedReference]

    private let cacheFileURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("breed-references-cache.json")
    }()

    init() {
        references = Self.loadBundled()
        if let cached = Self.load(from: cacheFileURL), !cached.isEmpty {
            references = cached
        }
    }

    func reference(forBreed breedName: String) -> BreedReference {
        BreedReferenceMatcher.reference(forBreed: breedName, in: references)
    }

    @discardableResult
    func refreshFromRemote() async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            let decoded = try JSONDecoder().decode([BreedReference].self, from: data)
            guard !decoded.isEmpty else { return false }
            references = decoded
            try? data.write(to: cacheFileURL)
            return true
        } catch {
            return false
        }
    }

    private static func loadBundled() -> [BreedReference] {
        guard let url = Bundle.main.url(forResource: "BreedReferences", withExtension: "json") else {
            return []
        }
        return load(from: url) ?? []
    }

    private static func load(from url: URL) -> [BreedReference]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([BreedReference].self, from: data)
    }
}
