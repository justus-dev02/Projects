import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("TaskService")
struct TaskServiceTests {
    @Test func createPlacesTaskAtTheEndOfTheTodoColumn() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let first = try stack.tasks.create(TaskDraft(title: "  First  "), in: project)
        let second = try stack.tasks.create(TaskDraft(title: "Second"), in: project)

        #expect(first.title == "First")
        #expect(first.status == .todo)
        #expect(first.column?.id == stack.column(project, .todo).id)
        #expect([first.order, second.order] as [Int] == [0, SparseOrder.spacing])
        #expect(first.createdAt == stack.now)
        #expect(first.sortedActivity.map(\.kind) == [.created])
        #expect(stack.observer.changedIDs == [first.id, second.id])
    }

    @Test func createInADoneColumnCompletesTheTask() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Done already"), in: project, column: stack.column(project, .done))
        #expect(task.status == .done)
        #expect(task.completedAt == stack.now)
    }

    @Test func createValidatesTheTitle() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        #expect(throws: ProjectsError.emptyField(.taskTitle)) {
            try stack.tasks.create(TaskDraft(title: "   "), in: project)
        }
        #expect(try stack.count(TaskItem.self) == 0)
    }

    @Test func updateRecordsActivityAndAppliesLabelsFromTheWorkspaceOnly() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let foreign = try stack.workspaces.createLabel(in: try stack.workspaces.create(name: "Other"), name: "Foreign", colorHex: "#000000")
        let label = try #require(workspace.sortedLabels.first)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)

        var draft = TaskDraft(task: task)
        draft.priority = .urgent
        draft.dueDate = stack.date(dayOffset: 2)
        draft.labelIDs = [label.id, foreign.id]
        draft.estimatedHours = -3
        try stack.tasks.update(task, with: draft)

        #expect(task.priority == .urgent)
        #expect(task.labelIDs == [label.id])
        #expect(task.estimatedHours == nil, "Negative estimates are discarded")
        let kinds = Set(task.sortedActivity.map(\.kind))
        #expect(kinds.isSuperset(of: [.priorityChanged, .dueDateChanged]))
    }

    @Test func setStatusMovesTheTaskIntoAMatchingColumn() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)

        try stack.tasks.setStatus(task, to: .review)
        #expect(task.column?.id == stack.column(project, .review).id)
        #expect(task.completedAt == nil)

        try stack.tasks.setStatus(task, to: .done)
        #expect(task.column?.id == stack.column(project, .done).id)
        #expect(task.completedAt == stack.now)

        try stack.tasks.toggleCompletion(task)
        #expect(task.status == .todo)
        #expect(task.completedAt == nil)
        #expect(task.sortedActivity.map(\.kind).contains(.reopened))
    }

    @Test func moveWithinAColumnReorders() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let todo = stack.column(project, .todo)
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        let c = try stack.tasks.create(TaskDraft(title: "C"), in: project)

        let keysBefore = [a.order, b.order]

        try stack.tasks.move(c, to: todo, at: 0)

        #expect(todo.sortedTasks.map(\.title) == ["C", "A", "B"])
        #expect([a.order, b.order] == keysBefore, "Only the moved task gets a new key")
        #expect(c.order < a.order)
    }

    @Test func moveBetweenTwoTasksTakesTheMidpoint() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let todo = stack.column(project, .todo)
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        let c = try stack.tasks.create(TaskDraft(title: "C"), in: project)

        try stack.tasks.move(c, to: todo, at: 1)

        #expect(todo.sortedTasks.map(\.title) == ["A", "C", "B"])
        #expect(c.order == SparseOrder.spacing / 2)
    }

    @Test("A used-up gap renumbers the column once")
    func moveRenumbersWhenNoKeyIsFree() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let todo = stack.column(project, .todo)
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        let c = try stack.tasks.create(TaskDraft(title: "C"), in: project)
        // Dense keys as written by version 1 of the app.
        a.order = 0
        b.order = 1
        c.order = 2

        try stack.tasks.move(c, to: todo, at: 1)

        #expect(todo.sortedTasks.map(\.title) == ["A", "C", "B"])
        #expect(todo.sortedTasks.map(\.order) == SparseOrder.renumbered(count: 3))
    }

    @Test func moveAcrossColumnsAdoptsTheStatusAndOnlyChangesTheMovedTask() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let todo = stack.column(project, .todo)
        let done = stack.column(project, .done)
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        let x = try stack.tasks.create(TaskDraft(title: "X"), in: project, column: done)

        try stack.tasks.move(a, to: done, at: 0)

        #expect(a.status == .done)
        #expect(a.completedAt == stack.now)
        #expect(done.sortedTasks.map(\.title) == ["A", "X"])
        #expect(todo.sortedTasks.map(\.title) == ["B"])
        #expect(b.order == SparseOrder.spacing, "Tasks left behind keep their keys")
        #expect(x.order == 0)
        #expect(a.order < x.order)
        #expect(a.sortedActivity.map(\.kind).contains(.moved))
    }

    @Test("Completing a recurring task creates the next occurrence")
    func recurrence() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let label = try #require(workspace.sortedLabels.first)
        let due = stack.date(dayOffset: 0, hour: 9)
        let task = try stack.tasks.create(TaskDraft(
            title: "Standup",
            dueDate: due,
            reminderDate: due.addingTimeInterval(-900),
            recurrence: RecurrenceRule(frequency: .weekly),
            labelIDs: [label.id]
        ), in: project)
        _ = try stack.tasks.addSubtask(to: task, title: "Prepare notes")
        try stack.tasks.toggleSubtask(try #require(task.sortedSubtasks.first))

        let next = try #require(try stack.tasks.setStatus(task, to: .done))

        let expectedDue = stack.calendar.date(byAdding: .day, value: 7, to: due)
        #expect(next.dueDate == expectedDue)
        #expect(next.reminderDate == expectedDue?.addingTimeInterval(-900))
        #expect(next.status == .todo)
        #expect(next.recurrence == RecurrenceRule(frequency: .weekly))
        #expect(next.labelIDs == [label.id])
        #expect(next.sortedSubtasks.map(\.isCompleted) == [false], "Subtasks are copied unchecked")
        #expect(task.recurrence == nil, "The rule moves to the new occurrence")

        // Reopening and completing again does not create another occurrence.
        try stack.tasks.toggleCompletion(task)
        #expect(try stack.tasks.toggleCompletion(task) == nil)
        #expect(try stack.count(TaskItem.self) == 2)
    }

    @Test func recurrenceStopsAtTheEndDate() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(
            title: "Once more",
            dueDate: stack.date(dayOffset: 0),
            recurrence: RecurrenceRule(frequency: .daily, endDate: stack.date(dayOffset: 0, hour: 23))
        ), in: project)
        #expect(try stack.tasks.setStatus(task, to: .done) == nil)
        #expect(try stack.count(TaskItem.self) == 1)
    }

    @Test func dependencies() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let (_, otherProject) = try stack.makeProject(name: "Other")
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        let c = try stack.tasks.create(TaskDraft(title: "C"), in: project)
        let foreign = try stack.tasks.create(TaskDraft(title: "Foreign"), in: otherProject)

        try stack.tasks.addDependency(b, blockedBy: a)
        try stack.tasks.addDependency(c, blockedBy: b)
        try stack.tasks.addDependency(c, blockedBy: b)
        #expect(c.blockers.map(\.title) == ["B"], "Adding twice is idempotent")
        #expect(b.isBlocked)
        #expect(a.blocking?.map(\.title) == ["B"])

        #expect(throws: ProjectsError.selfDependency) { try stack.tasks.addDependency(a, blockedBy: a) }
        #expect(throws: ProjectsError.dependencyCycle) { try stack.tasks.addDependency(a, blockedBy: c) }
        #expect(throws: ProjectsError.dependencyAcrossProjects) { try stack.tasks.addDependency(a, blockedBy: foreign) }

        try stack.tasks.setStatus(a, to: .done)
        #expect(!b.isBlocked)
        try stack.tasks.removeDependency(c, blockedBy: b)
        #expect(c.blockers.isEmpty)
    }

    @Test func subtasks() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let one = try stack.tasks.addSubtask(to: task, title: "One")
        _ = try stack.tasks.addSubtask(to: task, title: "Two")
        _ = try stack.tasks.addSubtask(to: task, title: "Three")

        try stack.tasks.toggleSubtask(one)
        #expect(task.completedSubtaskCount == 1)
        #expect(one.completedAt == stack.now)

        try stack.tasks.moveSubtasks(of: task, fromOffsets: IndexSet([0]), toOffset: 3)
        #expect(task.sortedSubtasks.map(\.title) == ["Two", "Three", "One"])

        try stack.tasks.renameSubtask(one, to: " Uno ")
        #expect(one.title == "Uno")
        #expect(throws: ProjectsError.emptyField(.subtaskTitle)) { try stack.tasks.renameSubtask(one, to: "") }
    }

    @Test func customFieldValues() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let points = try stack.projects.addCustomField(to: project, name: "Points", type: .number)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)

        try stack.tasks.setCustomFieldValue("8", for: points, on: task)
        #expect(task.customFieldValue(for: points)?.value == "8.0")

        #expect(throws: ProjectsError.invalidCustomFieldValue(fieldName: "Points")) {
            try stack.tasks.setCustomFieldValue("eight", for: points, on: task)
        }
        #expect(task.customFieldValue(for: points)?.value == "8.0", "Invalid input keeps the old value")

        try stack.tasks.setCustomFieldValue("", for: points, on: task)
        #expect(task.customFieldValue(for: points) == nil)
    }

    @Test func attachmentsAreLimitedInSize() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let tooLarge = Data(count: AttachmentPolicy.maxBytes + 1)
        #expect(throws: ProjectsError.attachmentTooLarge(maxBytes: AttachmentPolicy.maxBytes)) {
            try stack.tasks.addAttachment(to: task, fileName: "big.bin", contentType: "public.data", data: tooLarge)
        }
        let attachment = try stack.tasks.addAttachment(to: task, fileName: "notes.txt", contentType: "public.plain-text", data: Data("hi".utf8))
        #expect(attachment.byteCount == 2)
        #expect(attachment.data == Data("hi".utf8))
    }

    @Test func bulkOperations() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let tasks = try (1...3).map { try stack.tasks.create(TaskDraft(title: "T\($0)"), in: project) }

        #expect(try stack.tasks.setStatus(tasks, to: .inProgress) == 3)
        #expect(tasks.allSatisfy { $0.column?.status == .inProgress })
        try stack.tasks.setPriority(tasks, to: .high)
        #expect(tasks.allSatisfy { $0.priority == .high })
        let due = stack.date(dayOffset: 3)
        try stack.tasks.setDueDate(tasks, to: due)
        #expect(tasks.allSatisfy { $0.dueDate == due })
        try stack.tasks.delete(Array(tasks.prefix(2)))
        #expect(try stack.count(TaskItem.self) == 1)
    }

    @Test func duplicateCopiesSubtasksAndFields() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let field = try stack.projects.addCustomField(to: project, name: "Points", type: .number)
        let task = try stack.tasks.create(TaskDraft(title: "Original", priority: .high), in: project)
        _ = try stack.tasks.addSubtask(to: task, title: "Step")
        try stack.tasks.setCustomFieldValue("2", for: field, on: task)

        let copy = try stack.tasks.duplicate(task)

        #expect(copy.id != task.id)
        #expect(copy.title.hasPrefix("Original"))
        #expect(copy.priority == .high)
        #expect(copy.sortedSubtasks.map(\.title) == ["Step"])
        #expect(copy.customFieldValue(for: field)?.value == "2.0")
    }

    @Test func snoozeMovesTheReminder() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task", reminderDate: stack.now), in: project)
        try stack.tasks.snoozeReminder(of: task, by: 3600)
        #expect(task.reminderDate == stack.now.addingTimeInterval(3600))
    }

    @Test func commentsCanBeEdited() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let comment = try stack.tasks.addComment(to: task, text: "Frist")
        try stack.tasks.editComment(comment, text: "First")
        #expect(task.sortedComments.map(\.text) == ["First"])
        #expect(throws: ProjectsError.emptyField(.comment)) { try stack.tasks.addComment(to: task, text: " ") }
    }
}
