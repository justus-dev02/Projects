import Foundation

/// The statistic tiles on the task list that double as one-tap filters.
///
/// Each tile sets one criterion of a ``TaskFilter``; tapping an active tile clears it again. The
/// other criteria (search, labels, priorities) are left untouched.
public enum QuickFilter: CaseIterable, Sendable {
    /// All open tasks: clears the due date and status criteria.
    case open
    case dueToday
    case overdue
    case inProgress

    public func isActive(in filter: TaskFilter) -> Bool {
        switch self {
        case .open: filter.due == .any && filter.statuses.isEmpty
        case .dueToday: filter.due == .today
        case .overdue: filter.due == .overdue
        case .inProgress: filter.statuses == [.inProgress]
        }
    }

    /// The filter after tapping the tile.
    public func toggled(in filter: TaskFilter) -> TaskFilter {
        var result = filter
        switch self {
        case .open:
            result.due = .any
            result.statuses = []
        case .dueToday:
            result.due = isActive(in: filter) ? .any : .today
        case .overdue:
            result.due = isActive(in: filter) ? .any : .overdue
        case .inProgress:
            result.statuses = isActive(in: filter) ? [] : [.inProgress]
        }
        return result
    }
}

extension TaskFilter {
    /// Criteria the user added on a list that hides completed tasks by default. Hiding completed
    /// tasks is not counted, because it is that list's starting point.
    public var refinementCount: Int {
        activeCriteriaCount - (includeCompleted ? 0 : 1)
    }
}
