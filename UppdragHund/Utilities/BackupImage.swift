//
//  BackupImage.swift
//  UppdragHund
//
//  Säkerställer att bilder som ska molnbackas ryms i ett Firestore-dokument
//  (1 MB-tak). Nya foton komprimeras redan vid inmatning; detta är skyddsnätet
//  för äldre poster vars foto sparats i full upplösning.
//

import UIKit

enum BackupImage {
    /// Marginal under Firestores 1 MB så resten av dokumentet också får plats.
    static let maxBytes = 700_000

    /// Returnerar bilddatan oförändrad om den redan är liten nog, annars en
    /// nedskalad JPEG. nil bara om datan inte går att tolka som bild.
    static func fitted(_ data: Data?) -> Data? {
        guard let data else { return nil }
        if data.count <= maxBytes { return data }
        guard let image = UIImage(data: data) else { return nil }
        return PostImage.makeData(from: image)
    }
}
