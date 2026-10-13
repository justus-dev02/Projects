import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("ProjectService and WorkspaceService")
struct ProjectAndWorkspaceServiceTests {
    @Test func newWorkspacesGetDefaultLabels() throws {
        let stack = try TestStack()
        let workspace = try stack.workspaces.create(name: "Work")
        #expect(workspace.sortedLabels.count == 4)
        #expect(workspace.sortedLabels.map(\.order) == [0, 1, 2, 3])
        let empty = try stack.workspaces.create(name: "Empty", addDefaultLabels: false)
        #expect(empty.sortedLabels.isEmpty)
    }

    @Test func archivedWorkspacesAreHiddenByDefault() throws {
        let stack = try TestStack()
        let workspace = try stack.workspaces.create(name: "Old")
        try stack.workspaces.setArchived(workspace, true)
        #expect(try stack.workspaces.workspaces().isEmpty)
        #expect(try stack.workspaces.workspaces(includeArchived: true).count == 1)
    }

    @Test func newProjectsHaveOneColumnPerStatus() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        #expect(project.sortedColumns.map(\.status) == TaskStatus.allCases)
        #expect(project.sortedColumns.map(\.order) == [0, 1, 2, 3])
    }

    @Test func changingAColumnStatusUpdatesItsTasks() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let review = stack.column(project, .review)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project, column: review)

        try stack.projects.updateColumn(review, name: "QA", status: .done, colorHex: "#000000")

        #expect(review.name == "QA")
        #expect(task.status == .done)
        #expect(task.completedAt == stack.now)
    }

    @Test func reorderingColumns() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let done = stack.column(project, .done)
        try stack.projects.moveColumn(done, to: 0)
        #expect(project.sortedColumns.first?.id == done.id)
        try stack.projects.moveColumns(in: project, fromOffsets: IndexSet([0]), toOffset: 4)
        #expect(project.sortedColumns.last?.id == done.id)
        #expect(project.sortedColumns.map(\.order) == [0, 1, 2, 3])
    }

    @Test func choiceFieldsNeedOptionsAndClearRemovedValues() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        #expect(throws: ProjectsError.customFieldNeedsOptions) {
            try stack.projects.addCustomField(to: project, name: "Size", type: .choice, options: [" ", ""])
        }
        let size = try stack.projects.addCustomField(to: project, name: "Size", type: .choice, options: ["S", "M", "M", " L "])
        #expect(size.options == ["S", "M", "L"])

        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.setCustomFieldValue("L", for: size, on: task)
        try stack.projects.updateCustomField(size, name: "Size", options: ["S", "M"], isRequired: false)
        #expect(task.customFieldValue(for: size)?.value == "")
    }

    @Test func movingAProjectToAnotherWorkspaceDropsForeignLabels() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let target = try stack.workspaces.create(name: "Target")
        let label = try #require(workspace.sortedLabels.first)
        let task = try stack.tasks.create(TaskDraft(title: "Task", labelIDs: [label.id]), in: project)

        try stack.projects.move(project, to: target)

        #expect(project.workspace?.id == target.id)
        #expect(task.labelIDs.isEmpty)
    }

    @Test func projectStatistics() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let done = try stack.tasks.create(TaskDraft(title: "Done"), in: project)
        try stack.tasks.setStatus(done, to: .done)
        _ = try stack.tasks.create(TaskDraft(title: "Late", dueDate: stack.date(dayOffset: -1)), in: project)

        let stats = project.statistics(now: stack.now, calendar: stack.calendar)
        #expect(stats.total == 2)
        #expect(stats.completed == 1)
        #expect(stats.overdue == 1)
    }

    @Test func templatesCreateTasksWithSubtasks() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let template = try stack.templates.create(TemplateDraft(
            name: "Bug",
            category: .bug,
            taskTitle: "Bug: ",
            priority: .high,
            subtaskTitles: ["Reproduce", " ", "Fix"]
        ), in: workspace)
        #expect(template.subtaskTitles == ["Reproduce", "Fix"])

        let task = try stack.templates.instantiate(template, in: project)
        #expect(task.priority == .high)
        #expect(task.sortedSubtasks.map(\.title) == ["Reproduce", "Fix"])
        #expect(template.usageCount == 1)

        let fromTask = try stack.templates.create(from: task, name: "Copy")
        #expect(fromTask.subtaskTitles == ["Reproduce", "Fix"])
        #expect(workspace.sortedTemplates.count == 2)
    }
}
