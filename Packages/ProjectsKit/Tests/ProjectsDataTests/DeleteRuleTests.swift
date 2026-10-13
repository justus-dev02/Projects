import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

/// Regression tests for the delete rules. The previous schema cascaded from children to parents
/// (deleting a comment deleted its task and author), so every rule is pinned down here.
@Suite("Delete rules")
struct DeleteRuleTests {
    @Test func deletingACommentKeepsTheTask() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let comment = try stack.tasks.addComment(to: task, text: "Hello")

        try stack.tasks.deleteComment(comment)

        #expect(try stack.count(TaskItem.self) == 1)
        #expect(try stack.count(TaskComment.self) == 0)
        #expect(task.comments?.isEmpty == true)
    }

    @Test func deletingASubtaskOrAttachmentKeepsTheTask() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let subtask = try stack.tasks.addSubtask(to: task, title: "Sub")
        let attachment = try stack.tasks.addAttachment(to: task, fileName: "a.txt", contentType: "public.plain-text", data: Data("x".utf8))

        try stack.tasks.deleteSubtask(subtask)
        try stack.tasks.deleteAttachment(attachment)

        #expect(try stack.count(TaskItem.self) == 1)
        #expect(try stack.count(Subtask.self) == 0)
        #expect(try stack.count(TaskAttachment.self) == 0)
    }

    @Test func deletingALabelOnlyDetachesItFromTasks() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let label = try #require(workspace.sortedLabels.first)
        let task = try stack.tasks.create(TaskDraft(title: "Task", labelIDs: [label.id]), in: project)
        #expect(task.labelIDs == [label.id])

        try stack.workspaces.deleteLabel(label)

        #expect(try stack.count(TaskItem.self) == 1)
        #expect(task.labelIDs.isEmpty)
        #expect(try stack.count(Workspace.self) == 1)
    }

    @Test func deletingATaskKeepsLabelsBlockersAndProject() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let label = try #require(workspace.sortedLabels.first)
        let blocker = try stack.tasks.create(TaskDraft(title: "Blocker"), in: project)
        let task = try stack.tasks.create(TaskDraft(title: "Task", labelIDs: [label.id]), in: project)
        try stack.tasks.addDependency(task, blockedBy: blocker)
        _ = try stack.tasks.addSubtask(to: task, title: "Sub")
        _ = try stack.tasks.addComment(to: task, text: "Note")

        try stack.tasks.delete(task)

        #expect(try stack.count(TaskItem.self) == 1)
        #expect(try stack.count(TaskLabel.self) == workspace.sortedLabels.count)
        #expect(try stack.count(Project.self) == 1)
        #expect(try stack.count(Subtask.self) == 0, "Children of the task are deleted")
        #expect(try stack.count(TaskComment.self) == 0)
        #expect(try stack.count(ActivityEntry.self) == blocker.activity?.count)
        #expect(blocker.blocking?.isEmpty == true)
        #expect(stack.observer.deletedIDs == [task.id])
    }

    @Test func deletingAColumnMovesItsTasks() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let review = stack.column(project, .review)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project, column: review)

        try stack.projects.deleteColumn(review)

        #expect(try stack.count(TaskItem.self) == 1)
        #expect(task.column != nil)
        #expect(task.status == task.column?.status)
        #expect(project.sortedColumns.map(\.order) == [0, 1, 2])
    }

    @Test func deletingAColumnPrefersAColumnWithTheSameStatus() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let second = try stack.projects.addColumn(to: project, name: "Doing 2", status: .inProgress)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project, column: second)

        try stack.projects.deleteColumn(second)

        #expect(task.column?.id == stack.column(project, .inProgress).id)
        #expect(task.status == .inProgress)
    }

    @Test func theLastColumnCannotBeDeleted() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        for column in project.sortedColumns.dropLast() {
            try stack.projects.deleteColumn(column)
        }
        let last = try #require(project.sortedColumns.first)
        #expect(throws: ProjectsError.cannotDeleteLastColumn) {
            try stack.projects.deleteColumn(last)
        }
    }

    @Test func deletingAProjectCascadesButKeepsTheWorkspace() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let field = try stack.projects.addCustomField(to: project, name: "Points", type: .number)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.setCustomFieldValue("3", for: field, on: task)

        try stack.projects.delete(project)

        #expect(try stack.count(Workspace.self) == 1)
        #expect(try stack.count(TaskLabel.self) == workspace.sortedLabels.count)
        #expect(try stack.count(Project.self) == 0)
        #expect(try stack.count(BoardColumn.self) == 0)
        #expect(try stack.count(TaskItem.self) == 0)
        #expect(try stack.count(CustomFieldDefinition.self) == 0)
        #expect(try stack.count(CustomFieldValue.self) == 0)
    }

    @Test func deletingAWorkspaceRemovesEverythingInside() throws {
        let stack = try TestStack()
        try DemoDataSeeder(environment: stack.environment).seed()
        #expect(try stack.count(TaskItem.self) > 0)

        for workspace in try stack.workspaces.workspaces(includeArchived: true) {
            try stack.workspaces.delete(workspace)
        }

        for type in SchemaV1.models {
            #expect(try countRows(of: type, in: stack.context) == 0, "\(type) not empty")
        }
    }

    @Test func deletingACustomFieldKeepsTasks() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let field = try stack.projects.addCustomField(to: project, name: "Size", type: .choice, options: ["S", "M"])
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.setCustomFieldValue("M", for: field, on: task)

        try stack.projects.deleteCustomField(field)

        #expect(try stack.count(TaskItem.self) == 1)
        #expect(try stack.count(CustomFieldValue.self) == 0)
    }
}

/// Counts the rows of a model type that is only known at runtime.
private func countRows(of type: any PersistentModel.Type, in context: ModelContext) throws -> Int {
    func count<Model: PersistentModel>(_: Model.Type) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }
    return try count(type)
}
