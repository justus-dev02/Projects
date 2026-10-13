import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("TaskQueries")
struct QueryTests {
    /// Builds a varied, reproducible data set.
    private func seedVariedTasks(_ stack: TestStack, count: Int = 120) throws -> [TaskItem] {
        let (workspace, project) = try stack.makeProject()
        let labels = workspace.sortedLabels
        var generator = SeededGenerator(seed: 42)
        var tasks: [TaskItem] = []
        let words = ["Rechnung", "Über", "Design", "API", "Meeting", "Bug", "Release"]
        for index in 0..<count {
            let dayOffset = Int.random(in: -10...10, using: &generator)
            let hasDue = Bool.random(using: &generator)
            var draft = TaskDraft(
                title: "\(words.randomElement(using: &generator)!) \(index)",
                details: Bool.random(using: &generator) ? "Notizen zur Übersicht" : "",
                priority: TaskPriority.allCases.randomElement(using: &generator)!,
                dueDate: hasDue ? stack.date(dayOffset: dayOffset, hour: Int.random(in: 0...23, using: &generator)) : nil
            )
            if Bool.random(using: &generator) {
                draft.labelIDs = [labels.randomElement(using: &generator)!.id]
            }
            let task = try stack.tasks.create(draft, in: project)
            let status = TaskStatus.allCases.randomElement(using: &generator)!
            if status != .todo {
                try stack.tasks.setStatus(task, to: status)
            }
            tasks.append(task)
        }
        return tasks
    }

    @Test("Store predicates agree with the in-memory reference filter", arguments: [
        TaskFilter.all,
        TaskFilter(searchText: "uber"),
        TaskFilter(searchText: "übersicht"),
        TaskFilter(statuses: [.inProgress, .review]),
        TaskFilter(priorities: [.urgent, .low]),
        TaskFilter(due: .today),
        TaskFilter(due: .overdue),
        TaskFilter(due: .next7Days, includeCompleted: false),
        TaskFilter(due: .noDueDate),
        TaskFilter(searchText: "bug", statuses: [.todo], priorities: [.high, .urgent], due: .next7Days),
    ])
    func predicateMatchesReference(filter: TaskFilter) throws {
        let stack = try TestStack()
        let all = try seedVariedTasks(stack)

        let descriptor = TaskQueries.descriptor(filter: filter, sort: .createdAt, now: stack.now, calendar: stack.calendar)
        let fromStore = Set(try stack.context.fetch(descriptor).map(\.id))
        let reference = Set(all.filter { filter.matches($0, now: stack.now, calendar: stack.calendar) }.map(\.id))

        #expect(fromStore == reference)
    }

    @Test func projectScope() throws {
        let stack = try TestStack()
        let (_, first) = try stack.makeProject(name: "First")
        let (_, second) = try stack.makeProject(name: "Second")
        _ = try stack.tasks.create(TaskDraft(title: "A"), in: first)
        _ = try stack.tasks.create(TaskDraft(title: "B"), in: second)

        let descriptor = TaskQueries.descriptor(filter: .all, sort: .title, projectID: second.id, now: stack.now, calendar: stack.calendar)
        #expect(try stack.context.fetch(descriptor).map(\.title) == ["B"])
    }

    @Test func dueDateSortPutsMissingDatesLast() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        _ = try stack.tasks.create(TaskDraft(title: "None"), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Later", dueDate: stack.date(dayOffset: 5)), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Sooner", dueDate: stack.date(dayOffset: 1)), in: project)

        let descriptor = TaskQueries.descriptor(filter: .all, sort: .dueDate, now: stack.now, calendar: stack.calendar)
        let sorted = TaskQueries.finalize(try stack.context.fetch(descriptor), sort: .dueDate)
        #expect(sorted.map(\.title) == ["Sooner", "Later", "None"])
    }

    @Test func prioritySortIsByUrgency() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        for priority in [TaskPriority.low, .urgent, .medium, .high] {
            _ = try stack.tasks.create(TaskDraft(title: priority.title, priority: priority), in: project)
        }
        let descriptor = TaskQueries.descriptor(filter: .all, sort: .priority, now: stack.now, calendar: stack.calendar)
        #expect(try stack.context.fetch(descriptor).map(\.priority) == [.urgent, .high, .medium, .low])
    }

    @Test func dashboardSummaryAndLists() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        _ = try stack.tasks.create(TaskDraft(title: "Overdue", dueDate: stack.date(dayOffset: -2)), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Earlier today", dueDate: stack.date(dayOffset: 0, hour: 8)), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Later today", dueDate: stack.date(dayOffset: 0, hour: 20)), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Tomorrow", dueDate: stack.date(dayOffset: 1)), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Next month", dueDate: stack.date(dayOffset: 30)), in: project)
        let doing = try stack.tasks.create(TaskDraft(title: "Doing"), in: project)
        try stack.tasks.setStatus(doing, to: .inProgress)
        let done = try stack.tasks.create(TaskDraft(title: "Done", dueDate: stack.date(dayOffset: -1)), in: project)
        try stack.tasks.setStatus(done, to: .done)

        let summary = try stack.dashboard.summary()
        #expect(summary.openTasks == 6)
        #expect(summary.overdue == 2, "Overdue and earlier today; completed tasks never count")
        #expect(summary.dueToday == 2)
        #expect(summary.inProgress == 1)
        #expect(summary.completedLast7Days == 1)

        #expect(try stack.dashboard.focusTasks().map(\.title) == ["Overdue", "Earlier today", "Later today"])
        #expect(try stack.dashboard.upcomingTasks().map(\.title) == ["Tomorrow"])
    }

    @Test func upcomingRemindersSkipCompletedAndPastReminders() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        _ = try stack.tasks.create(TaskDraft(title: "Past", reminderDate: stack.date(dayOffset: -1)), in: project)
        _ = try stack.tasks.create(TaskDraft(title: "Future", reminderDate: stack.date(dayOffset: 1)), in: project)
        let done = try stack.tasks.create(TaskDraft(title: "Done", reminderDate: stack.date(dayOffset: 2)), in: project)
        try stack.tasks.setStatus(done, to: .done)

        let reminders = try stack.context.fetch(TaskQueries.upcomingReminders(now: stack.now, limit: 10))
        #expect(reminders.map(\.title) == ["Future"])
    }
}

/// A tiny deterministic random number generator (SplitMix64) for reproducible test data.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
