import AppIntents
import Foundation
import SwiftData
import ProjectsCore
import ProjectsData

/// A task as seen by Shortcuts, Siri, Spotlight and interactive widgets.
nonisolated struct TaskEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Task", numericFormat: "\(placeholder: .int) tasks")
    static let defaultQuery = TaskEntityQuery()

    let id: UUID
    let title: String
    let projectName: String
    let dueDate: Date?
    let isCompleted: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(projectName)",
            image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
        )
    }
}

extension TaskEntity {
    @MainActor
    init(_ task: TaskItem) {
        self.init(
            id: task.id,
            title: task.title,
            projectName: task.project?.name ?? "",
            dueDate: task.dueDate,
            isCompleted: task.isCompleted
        )
    }
}

/// Main-actor isolated so it can hold `@Dependency`; the protocol methods are `nonisolated` and hop
/// to the main actor for the data access.
struct TaskEntityQuery: nonisolated EntityStringQuery {
    @Dependency private var context: IntentContext

    nonisolated func entities(for identifiers: [UUID]) async throws -> [TaskEntity] {
        try await MainActor.run {
            let service = TaskService(environment: context.environment)
            return try identifiers.compactMap { try service.task(id: $0) }.map(TaskEntity.init)
        }
    }

    nonisolated func entities(matching string: String) async throws -> [TaskEntity] {
        try await MainActor.run {
            return try context.environment.context.fetch(TaskQueries.search(string, limit: 30)).map(TaskEntity.init)
        }
    }

    nonisolated func suggestedEntities() async throws -> [TaskEntity] {
        try await MainActor.run {
            let dashboard = DashboardService(environment: context.environment)
            return try (dashboard.focusTasks(limit: 10) + dashboard.upcomingTasks(limit: 10)).map(TaskEntity.init)
        }
    }
}
