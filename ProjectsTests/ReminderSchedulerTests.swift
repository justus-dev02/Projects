import Foundation
import SwiftData
import Testing
import ProjectsCore
import ProjectsData
import UserNotifications
@testable import Projects

@Suite("ReminderScheduler")
struct ReminderSchedulerTests {
    @Test func identifiersRoundTrip() {
        let id = UUID()
        #expect(ReminderScheduler.taskID(fromIdentifier: ReminderScheduler.identifier(for: id)) == id)
        #expect(ReminderScheduler.taskID(fromIdentifier: "other-\(id)") == nil)
    }

    @Test func remindersAreScheduledWhenTasksChange() async throws {
        let center = FakeNotificationCenter()
        let dependencies = AppDependencies.makeInMemory(seed: false, notificationCenter: center)
        let workspace = try dependencies.workspaces.create(name: "W")
        let project = try dependencies.projects.create(ProjectDraft(name: "P"), in: workspace)
        let reminder = Date.now.addingTimeInterval(3600)

        let task = try dependencies.tasks.create(TaskDraft(title: "Call Anna", reminderDate: reminder), in: project)

        let identifier = ReminderScheduler.identifier(for: task.id)
        #expect(await eventually { center.pending[identifier] != nil })
        let request = try #require(center.pending[identifier])
        #expect(request.content.title == "Call Anna")
        #expect(request.content.categoryIdentifier == ReminderScheduler.categoryIdentifier)
        #expect(request.content.userInfo[ReminderScheduler.taskIDKey] as? String == task.id.uuidString)

        try dependencies.tasks.setStatus(task, to: .done)
        #expect(await eventually { center.pending[identifier] == nil }, "Completing a task cancels its reminder")
    }

    @Test func deletingATaskCancelsItsReminder() async throws {
        let center = FakeNotificationCenter()
        let dependencies = AppDependencies.makeInMemory(seed: false, notificationCenter: center)
        let workspace = try dependencies.workspaces.create(name: "W")
        let project = try dependencies.projects.create(ProjectDraft(name: "P"), in: workspace)
        let task = try dependencies.tasks.create(TaskDraft(title: "T", reminderDate: .now.addingTimeInterval(600)), in: project)
        let identifier = ReminderScheduler.identifier(for: task.id)
        #expect(await eventually { center.pending[identifier] != nil })

        try dependencies.tasks.delete(task)

        #expect(center.pending[identifier] == nil)
    }

    @Test func pastRemindersAreNotPlanned() throws {
        let dependencies = AppDependencies.makeInMemory(seed: false)
        let workspace = try dependencies.workspaces.create(name: "W")
        let project = try dependencies.projects.create(ProjectDraft(name: "P"), in: workspace)
        let task = try dependencies.tasks.create(TaskDraft(title: "T", reminderDate: .now.addingTimeInterval(-60)), in: project)
        #expect(ReminderScheduler.plan(for: task, now: .now) == nil)
    }

    @Test func reconcileRemovesObsoleteRequestsAndAddsMissingOnes() async throws {
        let center = FakeNotificationCenter()
        let dependencies = AppDependencies.makeInMemory(seed: false, notificationCenter: center)
        let workspace = try dependencies.workspaces.create(name: "W")
        let project = try dependencies.projects.create(ProjectDraft(name: "P"), in: workspace)
        let task = try dependencies.tasks.create(TaskDraft(title: "T", reminderDate: .now.addingTimeInterval(600)), in: project)
        let staleIdentifier = ReminderScheduler.identifier(for: UUID())
        try await center.add(UNNotificationRequest(identifier: staleIdentifier, content: UNMutableNotificationContent(), trigger: nil))
        center.removePendingRequests(withIdentifiers: [ReminderScheduler.identifier(for: task.id)])

        await dependencies.reminders.reconcile(context: dependencies.container.mainContext)

        #expect(center.pending[staleIdentifier] == nil)
        #expect(center.pending[ReminderScheduler.identifier(for: task.id)] != nil)
    }

    @Test func authorizationIsOnlyRequestedOnce() async {
        let center = FakeNotificationCenter()
        center.status = .notDetermined
        let scheduler = ReminderScheduler(center: center)

        #expect(await scheduler.requestAuthorizationIfNeeded())
        #expect(await scheduler.requestAuthorizationIfNeeded())
        #expect(center.authorizationRequests == 1)
        #expect(scheduler.authorizationStatus == .authorized)
    }

    @Test func categoriesOfferCompleteAndSnooze() {
        let center = FakeNotificationCenter()
        ReminderScheduler(center: center).registerCategories()
        let actions = center.categories.first?.actions.map(\.identifier)
        #expect(actions == [ReminderScheduler.completeActionIdentifier, ReminderScheduler.snoozeActionIdentifier])
    }
}
