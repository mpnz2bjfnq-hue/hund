//
//  Community.swift
//  UppdragHund
//
//  Öppna stadsgrupper som vem som helst kan gå med i — till skillnad från
//  Team, som är slutna grupper man bjuds in till.
//
//  Varför inte bara ett Team med isPublic?
//  Team lagrar sina medlemmar *i* teamdokumentet (memberUids + memberNames).
//  Det bär en promenadgrupp med sex personer galant, men inte en stad:
//  dokumentgränsen i Firestore är 1 MiB (tar slut runt 12–13k medlemmar),
//  varje join skriver om hela dokumentet (~1 skrivning/sek och dokument), och
//  läsregeln kräver att man redan är medlem — så att bara *bläddra* bland
//  grupperna skulle dra ner varje medlemslista i sin helhet.
//
//  Här ligger medlemskapet i stället som ett dokument per medlem under
//  communities/{id}/members/{uid}. Att gå med är en skrivning till sitt eget
//  lilla dokument: ingen konflikt, ingen svällning, och listan kan visas utan
//  att läsa medlemmarna.
//
//  Städerna är en statisk lista i appen, inte dokument i Firestore. Det gör
//  att ingen kan äga eller råka radera "Göteborg", att det inte behövs något
//  seed-steg, och att reglerna bara behöver skydda medlemskapen. Priset är
//  att en ny stad kräver en appuppdatering — rimligt så länge listan är kort.
//

import Foundation

struct Community: Identifiable, Equatable, Hashable {
    /// Slug, används som dokument-ID i Firestore. Ändras aldrig — medlemskapen
    /// hänger på det.
    let id: String
    let city: String

    var name: String { "Hundägare i \(city)" }

    /// Grupperna appen erbjuder. Lägg till en stad genom att lägga till en rad
    /// här; ta aldrig bort en rad utan att först flytta medlemmarna, eftersom
    /// deras medlemsdokument då blir oåtkomliga från appen.
    static let all: [Community] = [
        Community(id: "stockholm", city: "Stockholm"),
        Community(id: "goteborg", city: "Göteborg"),
        Community(id: "malmo", city: "Malmö"),
        Community(id: "uppsala", city: "Uppsala"),
        Community(id: "linkoping", city: "Linköping"),
        Community(id: "orebro", city: "Örebro"),
        Community(id: "vasteras", city: "Västerås"),
        Community(id: "helsingborg", city: "Helsingborg"),
        Community(id: "jonkoping", city: "Jönköping"),
        Community(id: "umea", city: "Umeå")
    ]

    static func named(_ id: String) -> Community? {
        all.first { $0.id == id }
    }
}

/// En medlem i en stadsgrupp. Ett dokument per medlem under
/// communities/{communityId}/members/{uid} — dokument-ID är alltid uid, så
/// säkerhetsreglerna kan slå fast att man bara skriver sitt eget medlemskap.
struct CommunityMember: Codable, Identifiable, Equatable {
    /// Samma som uid (dokument-ID).
    var id: String { uid }
    var uid: String
    var displayName: String
    var joinedAt: Date
}
