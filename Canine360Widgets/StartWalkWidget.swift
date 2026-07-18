//
//  StartWalkWidget.swift
//  Canine360Widgets
//
//  "Starta promenad" från låsskärmen: en accessory-widget vid klockan,
//  och (iOS 18) en kontroll för Kontrollcentret/låsskärmens hörnknappar.
//  Båda öppnar appen rakt in i promenadskärmen som autostartar spårningen.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Låsskärms-/hemskärmswidget

struct StartWalkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StartWalkWidget", provider: StartWalkProvider()) { _ in
            StartWalkView()
        }
        .configurationDisplayName("Starta promenad")
        .description("Öppnar appen och startar en promenad direkt — för låsskärmen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct StartWalkEntry: TimelineEntry {
    let date: Date
}

struct StartWalkProvider: TimelineProvider {
    func placeholder(in context: Context) -> StartWalkEntry { StartWalkEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (StartWalkEntry) -> Void) {
        completion(StartWalkEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StartWalkEntry>) -> Void) {
        completion(Timeline(entries: [StartWalkEntry(date: .now)], policy: .never))
    }
}

private struct StartWalkView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "figure.walk")
                        .font(.title3.weight(.semibold))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Starta promenad")
                            .font(.headline)
                        Text("GPS + steg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "figure.walk")
                        .font(.title2.weight(.semibold))
                }
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(WidgetDeepLink.log("promenad", dogID: nil))
    }
}

// MARK: - Kontroll (Kontrollcenter + låsskärmens hörnknappar, iOS 18)

@available(iOS 18.0, *)
struct StartWalkControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "StartWalkControl") {
            ControlWidgetButton(action: StartWalkIntent()) {
                Label("Starta promenad", systemImage: "figure.walk")
            }
        }
        .displayName("Starta promenad")
        .description("Öppnar Canine360 och startar en promenad direkt.")
    }
}

@available(iOS 18.0, *)
struct StartWalkIntent: AppIntent {
    static let title: LocalizedStringResource = "Starta promenad"
    static let description = IntentDescription("Öppnar Canine360 och startar en promenad.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(WidgetDeepLink.log("promenad", dogID: nil)))
    }
}
