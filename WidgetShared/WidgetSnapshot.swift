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

    var dogName: String
    var dogBreed: String
    /// Liten JPEG-thumbnail (samma som hundprofilens avatar), valfri.
    var dogPhotoData: Data?
    /// Kommande händelser sorterade i datumordning (max en handfull).
    var upcoming: [Item]
    var generatedAt: Date
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
    static let logHealth = URL(string: "canine360://logga/halsa")!
    static let logMeal = URL(string: "canine360://logga/foder")!
    static let logTraining = URL(string: "canine360://logga/traning")!
    static let logDiary = URL(string: "canine360://logga/dagbok")!
}
