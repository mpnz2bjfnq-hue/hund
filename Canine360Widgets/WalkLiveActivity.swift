//
//  WalkLiveActivity.swift
//  Canine360Widgets
//
//  Låsskärms- och Dynamic Island-UI för en pågående promenad.
//  Klockan tickar själv via timerInterval — appen pushar bara distans
//  och pausläge.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Låsskärmen
            lockScreen(context: context)
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
                    timerText(context.state)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(distanceText(context.state.distanceMeters))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.brand)
                        Spacer()
                        if context.state.isPaused {
                            Label("Pausad", systemImage: "pause.fill")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "figure.walk.motion")
                                .foregroundStyle(WidgetTheme.brand)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(WidgetTheme.brand)
            } compactTrailing: {
                Text(distanceText(context.state.distanceMeters))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(WidgetTheme.brand)
            } minimal: {
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(WidgetTheme.brand)
            }
        }
    }

    private func lockScreen(context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        HStack(spacing: Theme_Spacing_l) {
            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundStyle(WidgetTheme.brand)
                .frame(width: 44, height: 44)
                .background(WidgetTheme.brand.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Promenad med \(context.attributes.dogName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetTheme.textPrimary)
                    .lineLimit(1)
                if context.state.isPaused {
                    Label("Pausad", systemImage: "pause.fill")
                        .font(.caption)
                        .foregroundStyle(WidgetTheme.textSecondary)
                } else {
                    timerText(context.state)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(WidgetTheme.textSecondary)
                }
            }
            Spacer(minLength: Theme_Spacing_s)
            Text(distanceText(context.state.distanceMeters))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.brand)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .activityBackgroundTint(WidgetTheme.base.opacity(0.85))
        .activitySystemActionForegroundColor(WidgetTheme.brand)
    }

    /// Självtickande tid när promenaden pågår; fryst text när den är pausad.
    @ViewBuilder
    private func timerText(_ state: WalkActivityAttributes.ContentState) -> some View {
        if state.isPaused {
            Text(formattedElapsed(state.elapsedSeconds))
        } else {
            Text(timerInterval: state.timerStart...Date(timeIntervalSinceNow: 60 * 60 * 24), countsDown: false)
        }
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func distanceText(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.2f km", meters / 1000)
            : "\(Int(meters)) m"
    }
}

// Widget-targetet har inte appens Theme — små lokala konstanter räcker.
private let Theme_Spacing_l: CGFloat = 16
private let Theme_Spacing_s: CGFloat = 8
