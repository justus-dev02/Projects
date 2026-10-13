import CoreSpotlight
import Foundation
import SwiftData
import Testing
import ProjectsCore
import ProjectsData
import UserNotifications
@testable import Projects

@Suite("AppDependencies")
struct AppDependenciesTests {
    private func makeProject(_ dependencies: AppDependencies) throws -> Project {
        let workspace = try dependencies.workspaces.create(name: "W")
        return try dependencies.projects.create(ProjectDraft(name: "P"), in: workspace)
    }

    @Test func inMemoryStackCanBeSeeded() throws {
        let dependencies = AppDependencies.makeInMemory(seed: true)
        #expect(try dependencies.workspaces.workspaces().count == 2)
        #expect(dependencies.storeIssue == nil)
    }

    @Test func dataChangesBumpTheVersion() throws {
        let dependencies = AppDependencies.makeInMemory(seed: false)
        let project = try makeProject(dependencies)
        let before = dependencies.dataVersion
        _ = try dependencies.tasks.create(TaskDraft(title: "T"), in: project)
        #expect(dependencies.dataVersion > before)
    }

    @Test("Deleting shows a toast whose action restores the tasks")
    func deleteAndUndo() throws {
        let dependencies = AppDependencies.makeInMemory(seed: false)
        let project = try makeProject(dependencies)
        let task = try dependencies.tasks.create(TaskDraft(title: "Restore me"), in: project)
        let id = task.id
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false

        dependencies.delete([task], undoManager: undoManager)
        #expect(try dependencies.tasks.task(id: id) == nil)
        #expect(dependencies.toasts.current?.actionTitle != nil)
        #expect(undoManager.canUndo)

        dependencies.toasts.runAction()

        #expect(try dependencies.tasks.task(id: id)?.title == "Restore me")
        #expect(dependencies.toasts.current == nil)
    }

    @Test func notificationActionsCompleteAndSnooze() throws {
        let dependencies = AppDependencies.makeInMemory(seed: false)
        let project = try makeProject(dependencies)
        let task = try dependencies.tasks.create(TaskDraft(title: "T", reminderDate: .now), in: project)

        dependencies.handleNotificationAction(ReminderScheduler.snoozeActionIdentifier, taskID: task.id)
        #expect((task.reminderDate ?? .distantPast) > .now.addingTimeInterval(3000))

        dependencies.handleNotificationAction(ReminderScheduler.completeActionIdentifier, taskID: task.id)
        #expect(task.isCompleted)

        dependencies.handleNotificationAction("com.apple.UNNotificationDefaultActionIdentifier", taskID: task.id)
        #expect(dependencies.router.todayPath == [.task(task.id)])
    }

    @Test func tasksAreIndexedInSpotlight() async throws {
        let index = FakeSearchIndex()
        let dependencies = AppDependencies.makeInMemory(seed: false, searchIndex: index)
        let project = try makeProject(dependencies)
        let task = try dependencies.tasks.create(TaskDraft(title: "Quarterly report", details: "Numbers"), in: project)
        let identifier = task.deepLink.url.absoluteString

        #expect(await eventually { index.indexed[identifier] != nil })
        let item = try #require(index.indexed[identifier])
        #expect(item.attributeSet.title == "Quarterly report")
        #expect(item.domainIdentifier == SpotlightIndexer.domainIdentifier)

        try dependencies.tasks.delete(task)
        #expect(await eventually { index.indexed[identifier] == nil })
    }

    @Test func fullReindexIndexesEveryTask() async throws {
        let index = FakeSearchIndex()
        let dependencies = AppDependencies.makeInMemory(seed: true, searchIndex: index)
        await dependencies.spotlight.reindexAll(context: dependencies.container.mainContext)
        #expect(index.deleteAllCount == 1)
        #expect(index.indexed.count == 9)
    }
}

@Suite("ErrorCenter and ToastCenter")
struct ErrorAndToastTests {
    @Test func projectsErrorsShowTheirLocalizedMessage() {
        let errors = ErrorCenter()
        let succeeded = errors.perform { throw ProjectsError.cannotDeleteLastColumn }
        #expect(!succeeded)
        #expect(errors.current?.message == ProjectsError.cannotDeleteLastColumn.errorDescription)
    }

    @Test func unexpectedErrorsShowAGenericMessage() {
        let errors = ErrorCenter()
        errors.present(CocoaError(.fileReadCorruptFile))
        #expect(errors.current?.message.isEmpty == false)
        #expect(errors.current?.message.contains("Cocoa") == false, "Internal descriptions never reach the user")
    }

    @Test func attemptReturnsTheValue() {
        let errors = ErrorCenter()
        #expect(errors.attempt { 42 } == 42)
        #expect(errors.current == nil)
    }

    @Test func toastActionRunsOnce() {
        let toasts = ToastCenter()
        var runs = 0
        toasts.show("Deleted", actionTitle: "Undo") { runs += 1 }
        toasts.runAction()
        toasts.runAction()
        #expect(runs == 1)
        #expect(toasts.current == nil)
    }
}
