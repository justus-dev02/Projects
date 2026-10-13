import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("ConsistencyService")
struct ConsistencyServiceTests {
    private func makeService(_ stack: TestStack) -> ConsistencyService {
        ConsistencyService(environment: stack.environment)
    }

    @Test func aConsistentStoreIsLeftAlone() throws {
        let stack = try TestStack()
        try DemoDataSeeder(environment: stack.environment).seed()
        let report = try makeService(stack).repair()
        #expect(report.isEmpty)
    }

    @Test("A status that disagrees with the column wins and the task moves")
    func statusWinsOverColumn() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        // Simulates an iCloud merge: the status changed on one device, the column on another.
        task.statusRaw = TaskStatus.review.rawValue

        let report = try makeService(stack).repair()

        #expect(report.movedToMatchingColumn == 1)
        #expect(task.column?.id == stack.column(project, .review).id)
        #expect(task.status == .review)
    }

    @Test func aTaskWithoutColumnIsPlaced() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        task.column = nil

        try makeService(stack).repair()

        #expect(task.column?.id == stack.column(project, .todo).id)
    }

    @Test func aTaskInAnotherProjectsColumnMovesHome() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let other = try stack.projects.create(ProjectDraft(name: "Other"), in: workspace)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        task.column = stack.column(other, .todo)

        try makeService(stack).repair()

        #expect(task.column?.project?.id == project.id)
    }

    @Test("Without a column for the status, the task adopts the column's status")
    func statusAdoptedWhenNoColumnMatches() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let review = stack.column(project, .review)
        for orphan in review.sortedTasks { orphan.column = stack.column(project, .todo) }
        try stack.projects.deleteColumn(review)
        task.statusRaw = TaskStatus.review.rawValue

        let report = try makeService(stack).repair()

        #expect(report.statusAdoptedFromColumn == 1)
        #expect(task.status == .todo)
    }

    @Test func completionDatesFollowTheStatus() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let open = try stack.tasks.create(TaskDraft(title: "Open"), in: project)
        let done = try stack.tasks.create(TaskDraft(title: "Done"), in: project, column: stack.column(project, .done))
        open.completedAt = stack.now
        done.completedAt = nil

        let report = try makeService(stack).repair()

        #expect(report.completionDateFixed == 2)
        #expect(open.completedAt == nil)
        #expect(done.completedAt != nil)
    }

    @Test func duplicateSortKeysAreRenumbered() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        b.order = a.order

        let report = try makeService(stack).repair()

        #expect(report.columnsRenumbered == 1)
        #expect(a.order != b.order)
        #expect(try makeService(stack).repair().isEmpty, "A second run finds nothing")
    }
}
