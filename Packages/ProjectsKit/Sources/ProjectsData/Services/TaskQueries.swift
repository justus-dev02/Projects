import Foundation
import SwiftData
import ProjectsCore

/// Builds fetch descriptors for task lists so that filtering and sorting run inside SQLite
/// instead of loading every task into memory.
public enum TaskQueries {
    /// A descriptor for the task list.
    ///
    /// Label filtering is not expressible as a store predicate for many-to-many relationships,
    /// so callers apply ``TaskFilter/matches(_:now:calendar:)`` afterwards when
    /// `filter.labelIDs` is not empty.
    public static func descriptor(
        filter: TaskFilter,
        sort: TaskSortOption,
        projectID: UUID? = nil,
        now: Date,
        calendar: Calendar,
        limit: Int? = nil
    ) -> FetchDescriptor<TaskItem> {
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: predicate(filter: filter, projectID: projectID, now: now, calendar: calendar),
            sortBy: sortDescriptors(for: sort)
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    public static func predicate(filter: TaskFilter, projectID: UUID?, now: Date, calendar: Calendar) -> Predicate<TaskItem> {
        let doneRaw = TaskStatus.done.rawValue
        let excludeCompleted = !filter.includeCompleted || filter.due == .overdue
        let statusRaws = filter.statuses.map(\.rawValue)
        let filterStatus = !statusRaws.isEmpty
        let priorityRaws = filter.priorities.map(\.rawValue)
        let filterPriority = !priorityRaws.isEmpty
        let search = filter.trimmedSearchText
        let filterSearch = !search.isEmpty
        let range = filter.due.dateRange(now: now, calendar: calendar)
        let filterRange = range != nil
        let lowerBound = range?.lowerBound ?? .distantPast
        let upperBound = range?.upperBound ?? .distantFuture
        let requireNoDueDate = filter.due == .noDueDate
        let filterProject = projectID != nil
        let project = projectID ?? UUID()
        // A missing due date maps to `farPast` for the lower and `farFuture` for the upper bound
        // check, so it can never satisfy both and is excluded from every date range.
        let farFuture = Date.distantFuture
        let farPast = Date.distantPast

        let statusPredicate = #Predicate<TaskItem> { task in
            (!excludeCompleted || task.statusRaw != doneRaw)
                && (!filterStatus || statusRaws.contains(task.statusRaw))
                && (!filterPriority || priorityRaws.contains(task.priorityRaw))
        }
        let datePredicate = #Predicate<TaskItem> { task in
            (!requireNoDueDate || task.dueDate == nil)
                && (!filterRange || ((task.dueDate ?? farPast) >= lowerBound && (task.dueDate ?? farFuture) < upperBound))
        }
        let textPredicate = #Predicate<TaskItem> { task in
            (!filterSearch || task.title.localizedStandardContains(search) || task.details.localizedStandardContains(search))
                && (!filterProject || task.project?.id == project)
        }
        return #Predicate<TaskItem> { task in
            statusPredicate.evaluate(task) && datePredicate.evaluate(task) && textPredicate.evaluate(task)
        }
    }

    public static func sortDescriptors(for sort: TaskSortOption) -> [SortDescriptor<TaskItem>] {
        switch sort {
        case .dueDate:
            [SortDescriptor(\.dueDate), SortDescriptor(\.priorityRaw, order: .reverse), SortDescriptor(\.createdAt)]
        case .priority:
            [SortDescriptor(\.priorityRaw, order: .reverse), SortDescriptor(\.dueDate), SortDescriptor(\.createdAt)]
        case .createdAt:
            [SortDescriptor(\.createdAt, order: .reverse)]
        case .title:
            [SortDescriptor(\.title, comparator: .localizedStandard), SortDescriptor(\.createdAt)]
        }
    }

    /// SQLite sorts `NULL` first. For due date sorting, tasks without a due date belong at the end.
    /// Because the store returns them as one contiguous block at the start, rotating that block
    /// is O(n) and does not touch any other property.
    public static func finalize(_ tasks: [TaskItem], sort: TaskSortOption) -> [TaskItem] {
        guard sort == .dueDate else { return tasks }
        let withoutDate = tasks.prefix { $0.dueDate == nil }
        return Array(tasks.dropFirst(withoutDate.count)) + withoutDate
    }

    /// Open tasks due within `range`, earliest first.
    public static func open(dueIn range: Range<Date>, limit: Int? = nil) -> FetchDescriptor<TaskItem> {
        let doneRaw = TaskStatus.done.rawValue
        let lower = range.lowerBound
        let upper = range.upperBound
        let farFuture = Date.distantFuture
        let farPast = Date.distantPast
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in
                task.statusRaw != doneRaw
                    && (task.dueDate ?? farPast) >= lower
                    && (task.dueDate ?? farFuture) < upper
            },
            sortBy: [SortDescriptor(\.dueDate), SortDescriptor(\.priorityRaw, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    /// Open tasks whose due date lies before `now`.
    public static func overdue(now: Date, limit: Int? = nil) -> FetchDescriptor<TaskItem> {
        open(dueIn: Date.distantPast..<now, limit: limit)
    }

    /// Open tasks due on the calendar day of `now` (including earlier hours of that day).
    public static func dueToday(now: Date, calendar: Calendar, limit: Int? = nil) -> FetchDescriptor<TaskItem> {
        let range = DueFilter.today.dateRange(now: now, calendar: calendar) ?? now..<now
        return open(dueIn: range, limit: limit)
    }

    /// Open tasks with a reminder in the future. Used to rebuild the notification schedule.
    public static func upcomingReminders(now: Date, limit: Int) -> FetchDescriptor<TaskItem> {
        let doneRaw = TaskStatus.done.rawValue
        let farPast = Date.distantPast
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in
                task.statusRaw != doneRaw && (task.reminderDate ?? farPast) > now
            },
            sortBy: [SortDescriptor(\.reminderDate)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    /// Text search across all tasks, used by App Intents and Spotlight.
    public static func search(_ text: String, limit: Int) -> FetchDescriptor<TaskItem> {
        descriptor(
            filter: TaskFilter(searchText: text),
            sort: .dueDate,
            now: .now,
            calendar: .current,
            limit: limit
        )
    }
}
