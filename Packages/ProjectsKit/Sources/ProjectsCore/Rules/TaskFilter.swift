import Foundation

/// The minimal view of a task that filtering needs. Implemented by the SwiftData model and by
/// lightweight test doubles.
public protocol TaskFilterable {
    var title: String { get }
    var details: String { get }
    var status: TaskStatus { get }
    var priority: TaskPriority { get }
    var dueDate: Date? { get }
    var labelIDs: Set<UUID> { get }
}

/// Restricts tasks by due date relative to "now".
public enum DueFilter: String, CaseIterable, Codable, Sendable, Identifiable {
    case any
    case overdue
    case today
    case next7Days
    case noDueDate

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .any: String(localized: "Any time", bundle: .module, comment: "Due date filter")
        case .overdue: String(localized: "Overdue", bundle: .module, comment: "Due date filter")
        case .today: String(localized: "Today", bundle: .module, comment: "Due date filter")
        case .next7Days: String(localized: "Next 7 days", bundle: .module, comment: "Due date filter")
        case .noDueDate: String(localized: "No due date", bundle: .module, comment: "Due date filter")
        }
    }

    /// The half-open interval a due date has to fall into, or `nil` when the filter is not
    /// expressed as an interval (`.any`, `.noDueDate`).
    public func dateRange(now: Date, calendar: Calendar) -> Range<Date>? {
        let startOfToday = calendar.startOfDay(for: now)
        switch self {
        case .any, .noDueDate:
            return nil
        case .overdue:
            return Date.distantPast..<now
        case .today:
            let end = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            return startOfToday..<end
        case .next7Days:
            let end = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now
            return startOfToday..<end
        }
    }
}

/// A combinable set of criteria for the task list.
///
/// ``matches(_:now:calendar:)`` is the reference implementation. The data layer translates the
/// same criteria into a SwiftData predicate; a test asserts that both agree.
public struct TaskFilter: Hashable, Codable, Sendable {
    public var searchText: String
    public var statuses: Set<TaskStatus>
    public var priorities: Set<TaskPriority>
    public var labelIDs: Set<UUID>
    public var due: DueFilter
    public var includeCompleted: Bool

    public init(
        searchText: String = "",
        statuses: Set<TaskStatus> = [],
        priorities: Set<TaskPriority> = [],
        labelIDs: Set<UUID> = [],
        due: DueFilter = .any,
        includeCompleted: Bool = true
    ) {
        self.searchText = searchText
        self.statuses = statuses
        self.priorities = priorities
        self.labelIDs = labelIDs
        self.due = due
        self.includeCompleted = includeCompleted
    }

    public static let all = TaskFilter()

    public var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Number of active criteria, excluding the search text. Shown as a badge on the filter button.
    public var activeCriteriaCount: Int {
        var count = 0
        if !statuses.isEmpty { count += 1 }
        if !priorities.isEmpty { count += 1 }
        if !labelIDs.isEmpty { count += 1 }
        if due != .any { count += 1 }
        if !includeCompleted { count += 1 }
        return count
    }

    public var isDefault: Bool {
        self == TaskFilter(searchText: searchText)
    }

    public func matches(_ task: some TaskFilterable, now: Date, calendar: Calendar) -> Bool {
        if !includeCompleted, task.status.isCompleted {
            return false
        }
        if !statuses.isEmpty, !statuses.contains(task.status) {
            return false
        }
        if !priorities.isEmpty, !priorities.contains(task.priority) {
            return false
        }
        if !labelIDs.isEmpty, labelIDs.isDisjoint(with: task.labelIDs) {
            return false
        }
        switch due {
        case .any:
            break
        case .noDueDate:
            if task.dueDate != nil { return false }
        case .overdue:
            // Completed tasks are never overdue.
            guard let dueDate = task.dueDate, !task.status.isCompleted,
                  let range = due.dateRange(now: now, calendar: calendar), range.contains(dueDate) else {
                return false
            }
        case .today, .next7Days:
            guard let dueDate = task.dueDate,
                  let range = due.dateRange(now: now, calendar: calendar), range.contains(dueDate) else {
                return false
            }
        }
        let query = trimmedSearchText
        if !query.isEmpty {
            let inTitle = task.title.localizedStandardContains(query)
            let inDetails = task.details.localizedStandardContains(query)
            if !inTitle, !inDetails { return false }
        }
        return true
    }
}

/// Sort orders offered in the task list.
public enum TaskSortOption: String, CaseIterable, Codable, Sendable, Identifiable {
    case dueDate
    case priority
    case createdAt
    case title

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dueDate: String(localized: "Due date", bundle: .module, comment: "Sort option")
        case .priority: String(localized: "Priority", bundle: .module, comment: "Sort option")
        case .createdAt: String(localized: "Newest first", bundle: .module, comment: "Sort option")
        case .title: String(localized: "Title", bundle: .module, comment: "Sort option")
        }
    }
}
