import AppIntents
import Foundation
import SwiftData
import Testing
import ProjectsData
@testable import Projects

/// App Intents receive their services through `@Dependency` instead of a global singleton.
///
/// The system fills `@Dependency` from `AppDependencyManager` when it runs an intent. Calling
/// `perform()` directly is outside that flow, so the tests inject the context themselves.
@MainActor
@Suite("App Intent dependencies", .serialized)
struct IntentDependencyTests {
    private func makeContext() -> (AppDependencies, IntentContext) {
        let dependencies = AppDependencies.makeInMemory(seed: false)
        let router = dependencies.router
        return (dependencies, IntentContext(environment: dependencies.environment) { router.handle($0) })
    }

    @Test func addTaskIntentWritesIntoTheRegisteredStore() async throws {
        let (dependencies, context) = makeContext()
        let workspace = try dependencies.workspaces.create(name: "Intents")
        let project = try dependencies.projects.create(ProjectDraft(name: "Inbox"), in: workspace)

        let intent = AddTaskIntent()
        intent.context = context
        intent.title = "Added through an intent"
        intent.project = ProjectEntity(project)
        _ = try await intent.perform()

        let title = "Added through an intent"
        let created = try dependencies.container.mainContext.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.title == title }))
        #expect(created.count == 1)
        #expect(created.first?.project?.id == project.id)
    }

    @Test func openTaskIntentNavigatesWithTheRegisteredRouter() async throws {
        let (dependencies, context) = makeContext()
        let id = UUID()
        let intent = OpenTaskIntent()
        intent.context = context
        intent.target = TaskEntity(id: id, title: "Task", projectName: "Inbox", dueDate: nil, isCompleted: false)

        _ = try await intent.perform()

        #expect(dependencies.router.todayPath.last == .task(id) || dependencies.router.tasksPath.last == .task(id)
            || dependencies.router.projectsPath.last == .task(id) || dependencies.router.templatesPath.last == .task(id))
    }
}
