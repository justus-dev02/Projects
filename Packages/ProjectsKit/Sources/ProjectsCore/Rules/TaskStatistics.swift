import Foundation

/// The facts about a task that statistics need, decoupled from the persistence model.
public struct TaskSnapshot: Hashable, Sendable {
    public var status: TaskStatus
    public var priority: TaskPriority
    public var dueDate: Date?
    public var completedAt: Date?

    public init(status: TaskStatus, priority: TaskPriority = .medium, dueDate: Date? = nil, completedAt: Date? = nil) {
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.completedAt = completedAt
    }

    public func isOverdue(now: Date) -> Bool {
        guard let dueDate, !status.isCompleted else { return false }
        return dueDate < now
    }
}

/// Aggregated progress numbers for a project, a workspace or everything.
public struct TaskStatistics: Equatable, Sendable {
    public let total: Int
    public let completed: Int
    public let inProgress: Int
    public let overdue: Int
    public let dueToday: Int
    public let completedLast7Days: Int

    public init(tasks: some Sequence<TaskSnapshot>, now: Date, calendar: Calendar) {
        var total = 0
        var completed = 0
        var inProgress = 0
        var overdue = 0
        var dueToday = 0
        var completedLast7Days = 0
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        for task in tasks {
            total += 1
            if task.status.isCompleted {
                completed += 1
                if let completedAt = task.completedAt, completedAt >= weekAgo {
                    completedLast7Days += 1
                }
            }
            if task.status == .inProgress || task.status == .review {
                inProgress += 1
            }
            if task.isOverdue(now: now) {
                overdue += 1
            }
            if let dueDate = task.dueDate, !task.status.isCompleted, calendar.isDate(dueDate, inSameDayAs: now) {
                dueToday += 1
            }
        }

        self.total = total
        self.completed = completed
        self.inProgress = inProgress
        self.overdue = overdue
        self.dueToday = dueToday
        self.completedLast7Days = completedLast7Days
    }

    /// Fraction of completed tasks in `0...1`. Zero when there are no tasks.
    public var completionRate: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }

    public var open: Int { total - completed }
}
