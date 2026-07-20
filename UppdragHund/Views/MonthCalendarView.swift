//
//  MonthCalendarView.swift
//  UppdragHund
//

import SwiftUI

struct MonthCalendarView: View {
    @Binding var displayedMonth: Date
    var heatPhase: (Date) -> HeatPhase? = { _ in nil }
    var isTestDay: (Date) -> Bool = { _ in false }
    var isPredicted: (Date) -> Bool = { _ in false }
    var hasNote: (Date) -> Bool = { _ in false }
    var hasHealthEvent: (Date) -> Bool = { _ in false }
    var onSelectDay: (Date) -> Void = { _ in }

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    /// Dagsrutan växer med textstorleken i stället för att klippa datumsiffran.
    @ScaledMetric(relativeTo: .body) private var dayCellHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Föregående månad")

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Nästa månad")
            }

            HStack {
                ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(daysInGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .animation(.default, value: displayedMonth)
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var daysInGrid: [Date?] {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for dayOffset in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstOfMonth) {
                days.append(date)
            }
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let firstWeekdayIndex = calendar.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let phase = heatPhase(date)
        let testDay = isTestDay(date)
        let predicted = isPredicted(date)
        let noted = hasNote(date)
        let health = hasHealthEvent(date)
        let isToday = calendar.isDateInToday(date)

        Button {
            onSelectDay(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.footnote)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Theme.Colors.heat.opacity(phase?.fillOpacity ?? 0))
                    )
                    .overlay(
                        // Efterlöp: tunn hel ring så fasen inte förväxlas med förlöp.
                        Circle().strokeBorder(
                            phase?.showsRing == true ? Theme.Colors.heat.opacity(0.7) : .clear,
                            lineWidth: 1.5
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(
                            predicted ? Theme.Colors.heat : .clear,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                    )
                    .overlay(
                        Circle().stroke(isToday ? Color.accentColor : .clear, lineWidth: 1.5)
                    )
                    .overlay(alignment: .topTrailing) {
                        // Rekommenderad provdag (dygn 8) — inte ett påstående om
                        // fertilitet, utan en uppmaning att mäta. Se HeatPhase.
                        if testDay {
                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.Colors.verified)
                                .offset(x: 3, y: -2)
                        }
                    }

                HStack(spacing: 3) {
                    Circle()
                        .fill(noted ? Color.accentColor : .clear)
                        .frame(width: 4, height: 4)
                    Circle()
                        .fill(health ? Theme.Colors.verified : .clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: dayCellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(
            for: date, phase: phase, testDay: testDay,
            predicted: predicted, noted: noted, health: health, isToday: isToday
        ))
    }

    private func accessibilityLabel(
        for date: Date, phase: HeatPhase?, testDay: Bool,
        predicted: Bool, noted: Bool, health: Bool, isToday: Bool
    ) -> String {
        var parts = [date.formatted(date: .complete, time: .omitted)]
        if isToday { parts.append("Idag") }
        if let phase { parts.append("Löp – \(phase.swedishCommon)") }
        if testDay { parts.append("Rekommenderad dag för progesteronprov") }
        if predicted { parts.append("Förväntat löp") }
        if noted { parts.append("Har dagboksinlägg") }
        if health { parts.append("Har hälsologg") }
        return parts.joined(separator: ", ")
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

#Preview {
    MonthCalendarView(displayedMonth: .constant(.now))
        .padding()
}
