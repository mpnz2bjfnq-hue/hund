//
//  WalkLiveActivity.swift
//  Canine360Widgets
//
//  Låsskärms- och Dynamic Island-UI för en pågående promenad: distans,
//  självtickande tid och tempo. Appen pushar bara distans/tempo/pausläge.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            LockScreenWalkView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(WidgetTheme.brand)
                        Text(context.attributes.dogName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Label("Pausad", systemImage: "pause.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(timerInterval: context.state.timerStart...farFuture, countsDown: false)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 60)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        islandMetric(
                            value: WalkFormatting.distance(context.state.distanceMeters),
                            unit: WalkFormatting.distanceUnit(context.state.distanceMeters),
                            label: String(localized: "DISTANS")
                        )
                        Spacer()
                        islandMetric(
                            value: WalkFormatting.pace(secondsPerKm: context.state.paceSecondsPerKm),
                            unit: "/km",
                            label: String(localized: "TEMPO")
                        )
                        Spacer()
                        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "figure.walk.motion")
                            .font(.title2)
                            .foregroundStyle(WidgetTheme.brand)
                    }
                }
            } compactLeading: {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(WidgetTheme.brand)
            } compactTrailing: {
                Text(WalkFormatting.distanceWithUnit(context.state.distanceMeters))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.brand)
            } minimal: {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(WidgetTheme.brand)
            }
        }
    }

    private func islandMetric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.brand)
                Text(unit)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
    }
}

private let farFuture = Date(timeIntervalSinceNow: 60 * 60 * 24)

/// Låsskärmskortet: Garmin-känsla med tre mätare i rad.
private struct LockScreenWalkView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "pawprint.fill")
                    .font(.caption)
                    .foregroundStyle(WidgetTheme.brand)
                Text("Promenad med \(context.attributes.dogName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
                if context.state.isPaused {
                    Label("Pausad", systemImage: "pause.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            HStack(alignment: .top) {
                metric(label: String(localized: "DISTANS")) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(WalkFormatting.distance(context.state.distanceMeters))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.brand)
                        Text(WalkFormatting.distanceUnit(context.state.distanceMeters))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetTheme.textSecondary)
                    }
                }
                Spacer()
                metric(label: String(localized: "TID")) {
                    Group {
                        if context.state.isPaused {
                            Text(WalkFormatting.elapsed(context.state.elapsedSeconds))
                        } else {
                            Text(timerInterval: context.state.timerStart...farFuture, countsDown: false)
                        }
                    }
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.textPrimary)
                }
                Spacer()
                metric(label: String(localized: "TEMPO")) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(WalkFormatting.pace(secondsPerKm: context.state.paceSecondsPerKm))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(WidgetTheme.textPrimary)
                        Text("/km")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetTheme.textSecondary)
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(WidgetTheme.base.opacity(0.88))
        .activitySystemActionForegroundColor(WidgetTheme.brand)
    }

    private func metric(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(WidgetTheme.textSecondary)
            content()
        }
    }
}
