//
//  WidgetSnapshot.swift
//  Canine360
//
//  Det lilla utsnitt av appdata som hemskärmswidgetarna visar.
//  Appen skriver, widgeten läser — via app-gruppens container.
//  Filen kompileras i BÅDE app-targetet och widget-targetet.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        enum Kind: String, Codable {
            case health
            case heat
            case meetup
        }

        var date: Date
        var title: String
        var subtitle: String?
        var kind: Kind
    }

    /// En hund som kan väljas i widgetens inställningar (långtryck → Redigera).
    struct DogData: Codable, Equatable, Identifiable {
        /// Hundens remoteID (uuidString) — samma id som djuplänkarna bär.
        var id: String
        var name: String
        var breed: String
        /// Liten JPEG-thumbnail (samma som hundprofilens avatar), valfri.
        var photoData: Data?
        /// Kommande händelser sorterade i datumordning (max en handfull).
        var upcoming: [Item]
        /// SharedModule-rawValues användaren får logga i (styr Snapplogga-
        /// knapparna: egen hund = alla, delad läsbehörighet = inga).
        var canLogModules: [String]
    }

    var dogs: [DogData]
    /// Hunden som är aktiv i appen — widgetens förval tills man väljer själv.
    var activeDogID: String?
    var generatedAt: Date

    func dog(withID id: String?) -> DogData? {
        if let id, let match = dogs.first(where: { $0.id == id }) { return match }
        return dogs.first(where: { $0.id == activeDogID }) ?? dogs.first
    }
}

enum WidgetStore {
    static let appGroupID = "group.ElzenenProjects.UppdragHund"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("widget-snapshot.json")
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Vid utloggning: widgeten ska inte visa förra kontots data.
    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// Djuplänkar widget → app. Appen registrerar schemat i sin Info.plist
/// och routar i MainTabView.
enum WidgetDeepLink {
    static let scheme = "canine360"

    static let home = URL(string: "canine360://hem")!

    /// canine360://logga/{halsa|foder|traning|dagbok}?dog={remoteID}
    static func log(_ kind: String, dogID: String?) -> URL {
        var string = "canine360://logga/\(kind)"
        if let dogID { string += "?dog=\(dogID)" }
        return URL(string: string) ?? home
    }
}
