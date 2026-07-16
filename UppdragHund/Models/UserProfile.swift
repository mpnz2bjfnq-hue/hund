//
//  UserProfile.swift
//  UppdragHund
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var displayName: String
    /// Användarnamnet (@handle). Vänner lägger till dig via detta.
    var handle: String
    var email: String?
    var createdAt: Date
    /// Publik summering av användarens hundar, för visning på profilen
    /// (även för vänner). Underhålls av ProfilePublisher.
    var dogSummaries: [DogSummary]?
    /// Komprimerad profilbild (~256px JPEG) lagrad direkt i profilen.
    /// Ingen Firebase Storage behövs i v1.
    var photoData: Data?
    /// Denormaliserat antal vänner — vänlistan är privat per säkerhetsreglerna,
    /// så antalet speglas hit (Cloud Function + self-heal vid egen laddning).
    var friendCount: Int?
}

extension UserProfile {
    /// Prefix på autogenererade handles (innan användaren valt ett riktigt @namn).
    static let autoHandlePrefix = "DOG-"

    /// Behöver profilen slutföras? (Inget valt användarnamn än.)
    var needsProfileSetup: Bool {
        handle.isEmpty || handle.hasPrefix(Self.autoHandlePrefix)
    }
}

struct DogSummary: Codable, Equatable, Identifiable {
    var remoteID: String
    var name: String
    var breed: String
    var birthDate: Date
    var sex: String
    /// Ängel 🌈 — hunden har gått bort. Optional för profiler publicerade
    /// innan fältet fanns (räknas då som aktiv hund).
    var isDeceased: Bool?
    /// Dödsdatum, för minnesraden på vänners profiler.
    var deceasedDate: Date?

    var id: String { remoteID }
    var isAngel: Bool { isDeceased == true }
}
