import Foundation
import SwiftData
import ProjectsCore

/// Numbers shown at the top of the dashboard.
public struct DashboardSummary: Equatable, Sendable {
    public let openTasks: Int
    public let dueToday: Int
    public let overdue: Int
    public let inProgress: Int
    public let completedLast7Days: Int

    public static let empty = DashboardSummary(openTasks: 0, dueToday: 0, overdue: 0, inProgress: 0, completedLast7Days: 0)
}

/// Aggregates for the dashboard. Uses `fetchCount` so that the numbers stay cheap even with
/// tens of thousands of tasks (see `docs/PERFORMANCE.md`).
public final class DashboardService {
    private let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    public func summary() throws -> DashboardSummary {
        let now = environment.now()
        let calendar = environment.calendar
        let doneRaw = TaskStatus.done.rawValue
        let inProgressRaw = TaskStatus.inProgress.rawValue
        let reviewRaw = TaskStatus.review.rawValue
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let farPast = Date.distantPast

        let open = try environment.count(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.statusRaw != doneRaw }))
        let dueToday = try environment.count(TaskQueries.dueToday(now: now, calendar: calendar))
        let overdue = try environment.count(TaskQueries.overdue(now: now))
        let inProgress = try environment.count(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.statusRaw == inProgressRaw || $0.statusRaw == reviewRaw }
        ))
        let completed = try environment.count(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.statusRaw == doneRaw && ($0.completedAt ?? farPast) >= weekAgo }
        ))
        return DashboardSummary(
            openTasks: open,
            dueToday: dueToday,
            overdue: overdue,
            inProgress: inProgress,
            completedLast7Days: completed
        )
    }

    /// Open tasks due today (including overdue ones), most urgent first.
    public func focusTasks(limit: Int = 20) throws -> [TaskItem] {
        let now = environment.now()
        let calendar = environment.calendar
        let endOfToday = DueFilter.today.dateRange(now: now, calendar: calendar)?.upperBound ?? now
        return try environment.fetch(TaskQueries.open(dueIn: Date.distantPast..<endOfToday, limit: limit))
    }

    /// Open tasks due in the next seven days after today.
    public func upcomingTasks(limit: Int = 20) throws -> [TaskItem] {
        let now = environment.now()
        let calendar = environment.calendar
        let startOfTomorrow = DueFilter.today.dateRange(now: now, calendar: calendar)?.upperBound ?? now
        let end = calendar.date(byAdding: .day, value: 7, to: startOfTomorrow) ?? startOfTomorrow
        return try environment.fetch(TaskQueries.open(dueIn: startOfTomorrow..<end, limit: limit))
    }
}
