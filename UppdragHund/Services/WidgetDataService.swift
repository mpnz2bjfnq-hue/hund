//
//  WidgetDataService.swift
//  UppdragHund
//
//  Bygger den lilla snapshot hemskärmswidgetarna visar och skriver den till
//  app-gruppen. Widgeten läser bara — allt datahämtande sker här i appen.
//

import Foundation
import WidgetKit

@MainActor
enum WidgetDataService {
    /// Uppdaterar widget-cachen från den aktiva hunden. `nil` (utloggad eller
    /// ingen hund) tömmer cachen så widgeten inte visar gammal data.
    static func refresh(activeDog: Dog?, uid: String?) async {
        guard let dog = activeDog, let uid else {
            WidgetStore.clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        var items: [WidgetSnapshot.Item] = []
        let now = Date.now

        // Framtida hälsohändelser (vet-bokningar, vaccinationer …).
        for event in dog.healthEvents where event.date > now {
            items.append(WidgetSnapshot.Item(
                date: event.date,
                title: event.title,
                subtitle: event.type.displayName,
                kind: .health
            ))
        }

        // Löp: pågående cykel eller nästa förväntade start (samma prediktion
        // som Hem/Kalender).
        if dog.tracksHeat {
            if let ongoing = dog.heatCycles.first(where: { $0.isOngoing }) {
                let day = HeatPhase.elapsedDays(in: ongoing, calendar: .current)
                items.append(WidgetSnapshot.Item(
                    date: now,
                    title: "Löp pågår – dag \(day)",
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
                        title: "Förväntat löp",
                        subtitle: nil,
                        kind: .heat
                    ))
                }
            }
        }

        // Nästa inbokade träff (egen eller tackat ja till).
        let meetups = await TeamsRepository.shared.upcomingMeetups(uid: uid)
        if let next = meetups
            .filter({ $0.date > now && ($0.ownerUid == uid || $0.goingUids.contains(uid)) })
            .min(by: { $0.date < $1.date }) {
            items.append(WidgetSnapshot.Item(
                date: next.date,
                title: next.title,
                subtitle: next.locationName,
                kind: .meetup
            ))
        }

        items.sort { $0.date < $1.date }

        WidgetStore.save(WidgetSnapshot(
            dogName: dog.name,
            dogBreed: dog.breed,
            dogPhotoData: dog.photoData,
            upcoming: Array(items.prefix(6)),
            generatedAt: now
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
