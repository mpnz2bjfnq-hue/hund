//
//  MonthCalendarView.swift
//  UppdragHund
//

import SwiftUI

struct MonthCalendarView: View {
    @Binding var displayedMonth: Date
    var isHighlighted: (Date) -> Bool = { _ in false }
    var isPredicted: (Date) -> Bool = { _ in false }
    var hasNote: (Date) -> Bool = { _ in false }
    var onSelectDay: (Date) -> Void = { _ in }

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

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
        let highlighted = isHighlighted(date)
        let predicted = isPredicted(date)
        let noted = hasNote(date)
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
                        Circle().fill(highlighted ? Color.orange.opacity(0.35) : Color.clear)
                    )
                    .overlay(
                        Circle().strokeBorder(
                            predicted ? Color.orange : .clear,
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                        )
                    )
                    .overlay(
                        Circle().stroke(isToday ? Color.accentColor : .clear, lineWidth: 1.5)
                    )

                Circle()
                    .fill(noted ? Color.accentColor : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: date, highlighted: highlighted, predicted: predicted, noted: noted, isToday: isToday))
    }

    private func accessibilityLabel(for date: Date, highlighted: Bool, predicted: Bool, noted: Bool, isToday: Bool) -> String {
        var parts = [date.formatted(date: .complete, time: .omitted)]
        if isToday { parts.append("Idag") }
        if highlighted { parts.append("Löp") }
        if predicted { parts.append("Förväntat löp") }
        if noted { parts.append("Har loggning") }
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
