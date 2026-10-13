import AppIntents
import Foundation
import SwiftData
import ProjectsData

/// A project as a parameter for Shortcuts and Siri.
nonisolated struct ProjectEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project", numericFormat: "\(placeholder: .int) projects")
    static let defaultQuery = ProjectEntityQuery()

    let id: UUID
    let name: String
    let workspaceName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(workspaceName)")
    }
}

extension ProjectEntity {
    @MainActor
    init(_ project: Project) {
        self.init(id: project.id, name: project.name, workspaceName: project.workspace?.name ?? "")
    }
}

/// Main-actor isolated so it can hold `@Dependency`; the protocol methods are `nonisolated` and hop
/// to the main actor for the data access.
struct ProjectEntityQuery: nonisolated EntityStringQuery {
    @Dependency private var context: IntentContext

    nonisolated func entities(for identifiers: [UUID]) async throws -> [ProjectEntity] {
        try await MainActor.run {
            let service = ProjectService(environment: context.environment)
            return try identifiers.compactMap { try service.project(id: $0) }.map(ProjectEntity.init)
        }
    }

    nonisolated func entities(matching string: String) async throws -> [ProjectEntity] {
        try await suggestedEntities().filter { $0.name.localizedStandardContains(string) }
    }

    nonisolated func suggestedEntities() async throws -> [ProjectEntity] {
        try await MainActor.run {
            let service = ProjectService(environment: context.environment)
            return try service.activeProjects().map(ProjectEntity.init)
        }
    }
}
