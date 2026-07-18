//
//  HeatGuideCard.swift
//  UppdragHund
//
//  Kunskapskort som visas under ett pågående löp: den genomsnittliga
//  tidslinjen, varför genomsnittet inte räcker, vad som faktiskt ger svar
//  och vad rasen har med saken att göra. Texterna bor i HeatGuide.
//

import SwiftUI

struct HeatGuideCard: View {
    /// Dag i det pågående löpet (1 = startdagen).
    let currentDay: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header

            if let hint = HeatGuide.todayHint(forDay: currentDay) {
                todayHintRow(hint)
            }

            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    timelineSection
                    infoSection(
                        icon: "exclamationmark.triangle.fill",
                        tint: Theme.Colors.warning,
                        title: HeatGuide.variationTitle,
                        body: HeatGuide.variationBody
                    )
                    infoSection(
                        icon: "cross.case.fill",
                        tint: Theme.Colors.verified,
                        title: HeatGuide.testTitle,
                        body: HeatGuide.testBody
                    )
                    infoSection(
                        icon: "pawprint.fill",
                        tint: Theme.Colors.textSecondary,
                        title: HeatGuide.breedTitle,
                        body: HeatGuide.breedBody
                    )
                    phasesSection
                    sourcesSection

                    Text(HeatGuide.disclaimer)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, Theme.Spacing.m)
            } label: {
                Text(isExpanded ? "Dölj" : "Läs mer om löpet")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
            }
            .tint(Theme.Colors.brand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var header: some View {
        Label("Så funkar löpet", systemImage: "book.fill")
            .font(.subheadline.bold())
            .foregroundStyle(Theme.Colors.textPrimary)
    }

    private func todayHintRow(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(Theme.Colors.warning)
            Text(hint)
                .font(.footnote)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.Colors.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        )
    }

    // MARK: - Tidslinje

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Genomsnittlig gång")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(HeatGuide.timeline.enumerated()), id: \.element.id) { index, step in
                    timelineRow(step, isLast: index == HeatGuide.timeline.count - 1)
                }
            }
        }
    }

    private func timelineRow(_ step: HeatGuide.TimelineStep, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            VStack(spacing: 0) {
                Circle()
                    .fill(step.isTestStep ? Theme.Colors.verified : Theme.Colors.heat)
                    .frame(width: 9, height: 9)
                if !isLast {
                    Rectangle()
                        .fill(Theme.Colors.textSecondary.opacity(0.3))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.s) {
                    Text(step.day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(step.isTestStep ? Theme.Colors.verified : Theme.Colors.heat)
                    Text(step.title)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : Theme.Spacing.m)
        }
    }

    // MARK: - Faser

    private var phasesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Löpets tre faser")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.textPrimary)

            ForEach([HeatPhase.proestrus, .estrus, .metestrus], id: \.self) { phase in
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Circle()
                        .fill(Theme.Colors.heat.opacity(phase.fillOpacity))
                        .overlay(
                            Circle().strokeBorder(
                                phase.showsRing ? Theme.Colors.heat.opacity(0.7) : .clear,
                                lineWidth: 1.5
                            )
                        )
                        .frame(width: 12, height: 12)
                        .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(phase.swedishCommon) (\(phase.displayName))")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(phase.signs)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("Förlöp och höglöp varar i snitt nio dagar vardera — men spannet är 3 dagar till 3 veckor. Färgerna i kalendern följer snittet.")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Byggblock

    private func infoSection(
        icon: String,
        tint: Color,
        title: String,
        body text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.textPrimary)
                .labelStyle(TintedIconLabelStyle(tint: tint))

            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Källor")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Colors.textPrimary)

            ForEach(HeatGuide.sources) { source in
                Link(destination: source.url) {
                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption2)
                        Text(source.title)
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(Theme.Colors.brand)
            }
        }
    }
}

/// Label där bara ikonen tonas — texten behåller sin egen färg.
private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            HeatGuideCard(currentDay: 6)
            HeatGuideCard(currentDay: 8)
            HeatGuideCard(currentDay: 12)
        }
        .padding()
    }
    .background(Theme.screenSurface)
}
