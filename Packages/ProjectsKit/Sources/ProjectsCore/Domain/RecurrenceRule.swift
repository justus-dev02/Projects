import Foundation

/// Describes how a task repeats. When a recurring task is completed, the next occurrence is
/// created with a due date computed by ``nextOccurrence(after:calendar:)``.
public struct RecurrenceRule: Codable, Hashable, Sendable {
    public enum Frequency: String, Codable, CaseIterable, Sendable, Identifiable {
        case daily
        case weekly
        case monthly
        case yearly

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .daily: String(localized: "Daily", bundle: .module, comment: "Recurrence frequency")
            case .weekly: String(localized: "Weekly", bundle: .module, comment: "Recurrence frequency")
            case .monthly: String(localized: "Monthly", bundle: .module, comment: "Recurrence frequency")
            case .yearly: String(localized: "Yearly", bundle: .module, comment: "Recurrence frequency")
            }
        }

        var calendarComponent: Calendar.Component {
            switch self {
            case .daily: .day
            case .weekly: .weekOfYear
            case .monthly: .month
            case .yearly: .year
            }
        }
    }

    public static let maximumInterval = 365

    public var frequency: Frequency
    /// Number of `frequency` units between two occurrences. Always within `1...maximumInterval`.
    public var interval: Int
    /// The last date on which an occurrence may fall. `nil` repeats forever.
    public var endDate: Date?

    public init(frequency: Frequency, interval: Int = 1, endDate: Date? = nil) {
        self.frequency = frequency
        self.interval = min(max(interval, 1), Self.maximumInterval)
        self.endDate = endDate
    }

    /// The date of the occurrence that follows `date`, or `nil` when the rule has ended.
    ///
    /// Month and year arithmetic is delegated to `Calendar`, which clamps to the last valid day
    /// (31 January + 1 month = 28/29 February).
    public func nextOccurrence(after date: Date, calendar: Calendar) -> Date? {
        guard let next = calendar.date(byAdding: frequency.calendarComponent, value: interval, to: date) else {
            return nil
        }
        if let endDate, next > endDate {
            return nil
        }
        return next
    }

    public var localizedDescription: String {
        switch frequency {
        case .daily:
            String(localized: "Every \(interval) days", bundle: .module, comment: "Recurrence description")
        case .weekly:
            String(localized: "Every \(interval) weeks", bundle: .module, comment: "Recurrence description")
        case .monthly:
            String(localized: "Every \(interval) months", bundle: .module, comment: "Recurrence description")
        case .yearly:
            String(localized: "Every \(interval) years", bundle: .module, comment: "Recurrence description")
        }
    }
}
