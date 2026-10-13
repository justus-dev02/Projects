import Foundation

/// Geometry for the timeline (Gantt) view.
public struct TimelineLayout: Sendable {
    public let start: Date
    public let dayCount: Int
    public let dayWidth: Double
    private let calendar: Calendar

    /// - Parameters:
    ///   - start: First visible day. Normalised to the start of that day.
    ///   - dayCount: Number of visible days (at least one).
    ///   - dayWidth: Width of one day in points.
    public init(start: Date, dayCount: Int, dayWidth: Double, calendar: Calendar) {
        self.start = calendar.startOfDay(for: start)
        self.dayCount = max(dayCount, 1)
        self.dayWidth = dayWidth
        self.calendar = calendar
    }

    public var totalWidth: Double { Double(dayCount) * dayWidth }

    public var end: Date {
        calendar.date(byAdding: .day, value: dayCount, to: start) ?? start
    }

    public var days: [Date] {
        (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Horizontal offset and width of a bar spanning the given days (inclusive), clipped to the
    /// visible range. Returns `nil` when the bar is not visible at all.
    public func bar(from barStart: Date, to barEnd: Date) -> (offset: Double, width: Double)? {
        let firstDay = calendar.startOfDay(for: min(barStart, barEnd))
        let lastDay = calendar.startOfDay(for: max(barStart, barEnd))
        guard let lastDayEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return nil }
        guard lastDayEnd > start, firstDay < end else { return nil }

        let clippedStart = max(firstDay, start)
        let clippedEnd = min(lastDayEnd, end)
        let startIndex = calendar.dateComponents([.day], from: start, to: clippedStart).day ?? 0
        let length = calendar.dateComponents([.day], from: clippedStart, to: clippedEnd).day ?? 0
        guard length > 0 else { return nil }
        return (Double(startIndex) * dayWidth, Double(length) * dayWidth)
    }
}
