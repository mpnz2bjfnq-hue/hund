//
//  WidgetDataService.swift
//  UppdragHund
//
//  Bygger den lilla snapshot hemskärmswidgetarna visar och skriver den till
//  app-gruppen. Widgeten läser bara — allt datahämtande sker här i appen.
//  Alla kontots hundar ingår, så användaren kan välja hund per widget.
//

import Foundation
import WidgetKit

@MainActor
enum WidgetDataService {
    /// Uppdaterar widget-cachen. Tom hundlista eller utloggad tömmer cachen
    /// så widgeten inte visar gammal data.
    static func refresh(dogs: [Dog], activeDog: Dog?, uid: String?) async {
        guard let uid, !dogs.isEmpty else {
            WidgetStore.clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let now = Date.now

        // Träffar är användarnivå (inte per hund) — hämta en gång och visa
        // nästa inbokade (egen eller tackat ja till) för alla hundar.
        let meetups = await TeamsRepository.shared.upcomingMeetups(uid: uid)
        let nextMeetup = meetups
            .filter { $0.date > now && ($0.ownerUid == uid || $0.goingUids.contains(uid)) }
            .min { $0.date < $1.date }

        var dogDatas: [WidgetSnapshot.DogData] = []
        for dog in dogs {
            guard let id = dog.remoteID?.uuidString else { continue }
            var items: [WidgetSnapshot.Item] = []

            // Framtida hälsohändelser (vet-bokningar, vaccinationer …).
            for event in dog.healthEvents where event.date > now {
                items.append(WidgetSnapshot.Item(
                    date: event.date,
                    // Titeln kan vara tom — då blir typen huvudtext (samma
                    // fallback som notiscentret) i stället för en tom rad.
                    title: event.title.isEmpty ? event.type.displayName : event.title,
                    subtitle: event.type.displayName,
                    kind: .health
                ))
            }

            // Löp: pågående cykel eller nästa förväntade start (samma
            // prediktion som Hem/Kalender).
            if dog.tracksHeat {
                if let ongoing = dog.heatCycles.first(where: { $0.isOngoing }) {
                    let day = HeatPhase.elapsedDays(in: ongoing, calendar: .current)
                    items.append(WidgetSnapshot.Item(
                        date: now,
                        title: String(localized: "Löp pågår – dag \(day)"),
                        subtitle: HeatPhase.isOverdue(day: day) ? nil : HeatPhase.forDayInCycle(day).swedishCommon,
                        kind: .heat
                    ))
                } else {
                    let completed = dog.heatCycles.filter { !$0.isOngoing }
                    let reference = BreedDataService.shared.reference(forBreed: dog.breed)
                    if let next = HeatPredictor.predict(completedCycles: completed, breedReference: reference)
                        .nextExpectedStartDate, next > now {
                        items.append(WidgetSnapshot.Item(
                            date: next,
                            title: String(localized: "Förväntat löp"),
                            subtitle: nil,
                            kind: .heat
                        ))
                    }
                }
            }

            if let next = nextMeetup {
                items.append(WidgetSnapshot.Item(
                    date: next.date,
                    title: next.title,
                    subtitle: next.locationName,
                    kind: .meetup
                ))
            }

            items.sort { $0.date < $1.date }

            dogDatas.append(WidgetSnapshot.DogData(
                id: id,
                name: dog.name,
                breed: dog.breed,
                photoData: dog.photoData,
                upcoming: Array(items.prefix(6)),
                canLogModules: canLogModules(for: dog)
            ))
        }

        WidgetStore.save(WidgetSnapshot(
            dogs: dogDatas,
            activeDogID: activeDog?.remoteID?.uuidString,
            generatedAt: now
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Vilka moduler Snapplogga-knapparna får visa för hunden: egen hund =
    /// alla, delad med skrivbehörighet = de delade modulerna, läs = inga.
    private static func canLogModules(for dog: Dog) -> [String] {
        guard dog.isShared else { return SharedModule.allCases.map(\.rawValue) }
        guard dog.sharePermission == .readWrite else { return [] }
        return dog.sharedModules.map(\.rawValue)
    }
}
