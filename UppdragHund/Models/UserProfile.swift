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
    /// Omslagsbild (16:9, hårt komprimerad) som visas bakom profilhuvudet.
    /// Alla bild-blobbar delar profil-dokumentets 1 MB-gräns — storlekarna
    /// hålls nere av beskärningens outputWidth + jpegQuality.
    var coverPhotoData: Data?
    /// Kort presentation ("🐾 Schäferägare från Örebro …").
    var bio: String?
    /// Upp till fyra favoritbilder (kvadratiska, hårt komprimerade).
    var favoritePhotoDatas: [Data]?
    /// Denormaliserat antal vänner — vänlistan är privat per säkerhetsreglerna,
    /// så antalet speglas hit (Cloud Function + self-heal vid egen laddning).
    var friendCount: Int?
    /// Instruktörskonto — krävs för att skapa kurs-/konsulentteam.
    /// Sätts ENDAST av servern (adminSetInstructor); reglerna nekar klienter.
    var instructor: Bool?
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
    /// Liten foto-thumbnail (~128px) så vänner ser hunden, inte en symbol.
    var photoData: Data?
    // Meriter (badges) — valfria för profiler publicerade före fälten.
    var hdResult: String?
    var edResult: String?
    var mentalTest: Bool?
    var showMerit: Bool?
    var vaccinated: Bool?
    var chipped: Bool?

    var id: String { remoteID }
    var isAngel: Bool { isDeceased == true }

    var badges: [DogBadge] {
        DogBadge.badges(
            hdResult: hdResult,
            edResult: edResult,
            mentalTest: mentalTest == true,
            showMerit: showMerit == true,
            vaccinated: vaccinated == true,
            chipped: chipped == true
        )
    }
}
