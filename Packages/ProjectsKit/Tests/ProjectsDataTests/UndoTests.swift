import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

/// "Undo delete" is implemented explicitly because SwiftData's undo manager crashes when undoing
/// a saved deletion. These tests pin down that a restore is complete.
@Suite("Undo delete")
struct UndoTests {
    @Test func restoreBringsBackTheTaskWithEverythingAttached() throws {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let label = try #require(workspace.sortedLabels.first)
        let field = try stack.projects.addCustomField(to: project, name: "Points", type: .number)
        let blocker = try stack.tasks.create(TaskDraft(title: "Blocker"), in: project)
        let task = try stack.tasks.create(TaskDraft(title: "Keep me", labelIDs: [label.id]), in: project, column: stack.column(project, .review))
        let dependent = try stack.tasks.create(TaskDraft(title: "Dependent"), in: project)
        try stack.tasks.addDependency(task, blockedBy: blocker)
        try stack.tasks.addDependency(dependent, blockedBy: task)
        _ = try stack.tasks.addSubtask(to: task, title: "Child")
        _ = try stack.tasks.addComment(to: task, text: "Note")
        _ = try stack.tasks.addAttachment(to: task, fileName: "a.txt", contentType: "public.plain-text", data: Data("abc".utf8))
        try stack.tasks.setCustomFieldValue("3", for: field, on: task)
        let originalID = task.id
        let activityCount = task.sortedActivity.count

        let deleted = try stack.tasks.deleteUndoably([task])
        #expect(try stack.tasks.task(id: originalID) == nil)
        #expect(!dependent.isBlocked)

        let restored = try #require(try stack.tasks.restore(deleted).first)

        #expect(restored.id == originalID)
        #expect(restored.title == "Keep me")
        #expect(restored.column?.status == .review)
        #expect(restored.labelIDs == [label.id])
        #expect(restored.sortedSubtasks.map(\.title) == ["Child"])
        #expect(restored.sortedComments.map(\.text) == ["Note"])
        #expect(restored.sortedAttachments.first?.data == Data("abc".utf8))
        #expect(restored.customFieldValue(for: field)?.value == "3.0")
        #expect(restored.blockers.map(\.title) == ["Blocker"])
        #expect(dependent.blockers.map(\.id) == [originalID])
        #expect(restored.sortedActivity.count == activityCount)
        #expect(stack.observer.changedIDs.last == originalID)
    }

    @Test func restoringSeveralTasksKeepsLinksBetweenThem() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let a = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let b = try stack.tasks.create(TaskDraft(title: "B"), in: project)
        try stack.tasks.addDependency(b, blockedBy: a)

        let deleted = try stack.tasks.deleteUndoably([a, b])
        #expect(deleted.count == 2)
        let restored = try stack.tasks.restore(deleted)

        let restoredB = try #require(restored.first { $0.title == "B" })
        #expect(restoredB.blockers.map(\.title) == ["A"])
    }

    @Test func restoreSkipsTasksWhoseProjectIsGone() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "A"), in: project)
        let deleted = try stack.tasks.deleteUndoably([task])
        try stack.projects.delete(project)

        #expect(try stack.tasks.restore(deleted).isEmpty)
        #expect(try stack.count(TaskItem.self) == 0)
    }
}
