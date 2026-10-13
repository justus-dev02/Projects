import Foundation

/// A single cell of a month grid.
public struct CalendarDay: Hashable, Identifiable, Sendable {
    public let date: Date
    public let isInDisplayedMonth: Bool
    public let isToday: Bool

    public var id: Date { date }
}

/// Builds the cells of a month view, honouring the calendar's first weekday
/// (Sunday in the US, Monday in Germany).
public enum CalendarGrid {
    /// Returns complete weeks covering the month that contains `month`.
    /// The result always has a multiple of seven elements (28, 35 or 42).
    public static func days(forMonthContaining month: Date, today: Date, calendar: Calendar) -> [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth) else {
            return []
        }

        var days: [CalendarDay] = []
        var current = firstWeek.start
        while current < lastWeek.end {
            days.append(CalendarDay(
                date: current,
                isInDisplayedMonth: calendar.isDate(current, equalTo: month, toGranularity: .month),
                isToday: calendar.isDate(current, inSameDayAs: today)
            ))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    /// Short weekday symbols ordered by the calendar's first weekday.
    public static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }
}
