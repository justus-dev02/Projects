import Foundation
import SwiftData
import ProjectsCore

/// Creates, edits and deletes workspaces and their labels.
public final class WorkspaceService {
    private let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    // MARK: Queries

    public func workspace(id: UUID) throws -> Workspace? {
        var descriptor = FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try environment.fetch(descriptor).first
    }

    public func workspaces(includeArchived: Bool = false) throws -> [Workspace] {
        let descriptor = FetchDescriptor<Workspace>(
            predicate: #Predicate { includeArchived || !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try environment.fetch(descriptor)
    }

    // MARK: Workspaces

    @discardableResult
    public func create(
        name: String,
        details: String = "",
        colorHex: String = ColorPalette.indigo,
        symbolName: String = "briefcase",
        addDefaultLabels: Bool = true
    ) throws -> Workspace {
        let workspace = Workspace(
            name: try Validation.name(name, field: .workspaceName),
            details: try Validation.details(details, field: .workspaceName),
            colorHex: colorHex,
            symbolName: symbolName
        )
        let now = environment.now()
        workspace.createdAt = now
        workspace.updatedAt = now
        environment.context.insert(workspace)

        if addDefaultLabels {
            let defaults: [(String, String)] = [
                (String(localized: "Bug", bundle: .module, comment: "Default label"), ColorPalette.red),
                (String(localized: "Feature", bundle: .module, comment: "Default label"), ColorPalette.indigo),
                (String(localized: "Improvement", bundle: .module, comment: "Default label"), ColorPalette.green),
                (String(localized: "Docs", bundle: .module, comment: "Default label"), ColorPalette.gray),
            ]
            for (index, entry) in defaults.enumerated() {
                let label = TaskLabel(name: entry.0, colorHex: entry.1, order: index)
                environment.context.insert(label)
                label.workspace = workspace
            }
        }

        try environment.save()
        Log.services.info("Workspace created")
        return workspace
    }

    public func update(
        _ workspace: Workspace,
        name: String,
        details: String,
        colorHex: String,
        symbolName: String
    ) throws {
        workspace.name = try Validation.name(name, field: .workspaceName)
        workspace.details = try Validation.details(details, field: .workspaceName)
        workspace.colorHex = colorHex
        workspace.symbolName = symbolName
        workspace.updatedAt = environment.now()
        try environment.save()
    }

    public func setArchived(_ workspace: Workspace, _ isArchived: Bool) throws {
        workspace.isArchived = isArchived
        workspace.updatedAt = environment.now()
        try environment.save()
    }

    /// Deletes the workspace with all projects, tasks, labels and templates.
    public func delete(_ workspace: Workspace) throws {
        let deletedTaskIDs = workspace.projectList.flatMap(\.taskList).map(\.id)
        environment.context.delete(workspace)
        try environment.save(deleted: deletedTaskIDs)
        Log.services.info("Workspace deleted with \(deletedTaskIDs.count) tasks")
    }

    // MARK: Labels

    @discardableResult
    public func createLabel(in workspace: Workspace, name: String, colorHex: String) throws -> TaskLabel {
        let order = (workspace.labels ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let label = TaskLabel(name: try Validation.name(name, field: .labelName, maxLength: 40), colorHex: colorHex, order: order)
        environment.context.insert(label)
        label.workspace = workspace
        try environment.save()
        return label
    }

    public func updateLabel(_ label: TaskLabel, name: String, colorHex: String) throws {
        label.name = try Validation.name(name, field: .labelName, maxLength: 40)
        label.colorHex = colorHex
        try environment.save(changed: label.tasks ?? [])
    }

    /// Removes the label from all tasks and deletes it. Tasks are not affected otherwise.
    public func deleteLabel(_ label: TaskLabel) throws {
        let affected = label.tasks ?? []
        environment.context.delete(label)
        try environment.save(changed: affected)
    }
}
