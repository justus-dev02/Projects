import Foundation
import SwiftData
import ProjectsCore

/// The editable properties of a project.
public struct ProjectDraft: Equatable, Sendable {
    public var name: String
    public var details: String
    public var colorHex: String
    public var symbolName: String
    public var status: ProjectStatus
    public var startDate: Date?
    public var dueDate: Date?

    public init(
        name: String = "",
        details: String = "",
        colorHex: String = ColorPalette.indigo,
        symbolName: String = "folder",
        status: ProjectStatus = .active,
        startDate: Date? = nil,
        dueDate: Date? = nil
    ) {
        self.name = name
        self.details = details
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.status = status
        self.startDate = startDate
        self.dueDate = dueDate
    }

    public init(project: Project) {
        self.init(
            name: project.name,
            details: project.details,
            colorHex: project.colorHex,
            symbolName: project.symbolName,
            status: project.status,
            startDate: project.startDate,
            dueDate: project.dueDate
        )
    }
}

/// Creates and edits projects, their board columns and custom field definitions.
public final class ProjectService {
    private let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    // MARK: Queries

    public func project(id: UUID) throws -> Project? {
        var descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try environment.fetch(descriptor).first
    }

    /// All projects that are not archived and whose workspace is not archived, newest first.
    public func activeProjects() throws -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try environment.fetch(descriptor).filter { $0.workspace?.isArchived == false }
    }

    // MARK: Projects

    @discardableResult
    public func create(_ draft: ProjectDraft, in workspace: Workspace) throws -> Project {
        let project = Project(
            name: try Validation.name(draft.name, field: .projectName),
            details: try Validation.details(draft.details, field: .projectName),
            colorHex: draft.colorHex,
            symbolName: draft.symbolName
        )
        project.status = draft.status
        project.startDate = draft.startDate
        project.dueDate = draft.dueDate
        let now = environment.now()
        project.createdAt = now
        project.updatedAt = now
        environment.context.insert(project)
        project.workspace = workspace

        let defaultColumns: [(String, TaskStatus, String)] = [
            (String(localized: "To Do", bundle: .module, comment: "Default board column"), .todo, ColorPalette.gray),
            (String(localized: "In Progress", bundle: .module, comment: "Default board column"), .inProgress, ColorPalette.blue),
            (String(localized: "Review", bundle: .module, comment: "Default board column"), .review, ColorPalette.orange),
            (String(localized: "Done", bundle: .module, comment: "Default board column"), .done, ColorPalette.green),
        ]
        for (index, entry) in defaultColumns.enumerated() {
            let column = BoardColumn(name: entry.0, status: entry.1, colorHex: entry.2, order: index)
            column.createdAt = now
            environment.context.insert(column)
            column.project = project
        }

        try environment.save()
        Log.services.info("Project created")
        return project
    }

    public func update(_ project: Project, with draft: ProjectDraft) throws {
        project.name = try Validation.name(draft.name, field: .projectName)
        project.details = try Validation.details(draft.details, field: .projectName)
        project.colorHex = draft.colorHex
        project.symbolName = draft.symbolName
        project.status = draft.status
        project.startDate = draft.startDate
        project.dueDate = draft.dueDate
        project.updatedAt = environment.now()
        try environment.save()
    }

    public func setArchived(_ project: Project, _ isArchived: Bool) throws {
        project.isArchived = isArchived
        project.updatedAt = environment.now()
        try environment.save(changed: project.taskList)
    }

    /// Moves a project into another workspace. Labels of the old workspace are removed from its
    /// tasks because labels are scoped to a workspace.
    public func move(_ project: Project, to workspace: Workspace) throws {
        guard project.workspace?.id != workspace.id else { return }
        for task in project.taskList {
            task.labels = []
        }
        project.workspace = workspace
        project.updatedAt = environment.now()
        try environment.save(changed: project.taskList)
    }

    public func delete(_ project: Project) throws {
        let deletedTaskIDs = project.taskList.map(\.id)
        environment.context.delete(project)
        try environment.save(deleted: deletedTaskIDs)
    }

    // MARK: Columns

    @discardableResult
    public func addColumn(to project: Project, name: String, status: TaskStatus, colorHex: String = ColorPalette.gray) throws -> BoardColumn {
        let order = (project.columns ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let column = BoardColumn(
            name: try Validation.name(name, field: .columnName, maxLength: 40),
            status: status,
            colorHex: colorHex,
            order: order
        )
        column.createdAt = environment.now()
        environment.context.insert(column)
        column.project = project
        try environment.save()
        return column
    }

    /// Renames a column and changes the status it represents. Tasks in the column adopt the new
    /// status so that board and status never disagree.
    public func updateColumn(_ column: BoardColumn, name: String, status: TaskStatus, colorHex: String) throws {
        column.name = try Validation.name(name, field: .columnName, maxLength: 40)
        column.colorHex = colorHex
        var changed: [TaskItem] = []
        if column.status != status {
            column.status = status
            let now = environment.now()
            for task in column.tasks ?? [] where task.status != status {
                TaskStatusTransition.apply(status, to: task, now: now)
                changed.append(task)
            }
        }
        try environment.save(changed: changed)
    }

    /// Deletes a column. Its tasks move to the first remaining column with the same status, or
    /// to the first column of the board.
    /// - Throws: ``ProjectsError/cannotDeleteLastColumn`` when it is the only column.
    public func deleteColumn(_ column: BoardColumn) throws {
        guard let project = column.project else {
            environment.context.delete(column)
            try environment.save()
            return
        }
        let remaining = project.sortedColumns.filter { $0.id != column.id }
        guard let fallback = remaining.first(where: { $0.status == column.status }) ?? remaining.first else {
            throw ProjectsError.cannotDeleteLastColumn
        }

        let moved = column.sortedTasks
        let now = environment.now()
        var nextOrder = (fallback.tasks ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        for task in moved {
            task.column = fallback
            task.order = nextOrder
            nextOrder += 1
            if task.status != fallback.status {
                TaskStatusTransition.apply(fallback.status, to: task, now: now)
            }
            task.updatedAt = now
        }
        environment.context.delete(column)
        for (index, remainingColumn) in remaining.enumerated() {
            remainingColumn.order = index
        }
        try environment.save(changed: moved)
    }

    public func moveColumns(in project: Project, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let columns = project.sortedColumns
        let ids = OrderedMove.move(columns.map(\.id), fromOffsets: source, toOffset: destination)
        apply(order: ids, to: columns)
        try environment.save()
    }

    public func moveColumn(_ column: BoardColumn, to index: Int) throws {
        guard let project = column.project else { return }
        let columns = project.sortedColumns
        let ids = OrderedMove.move(column.id, in: columns.map(\.id), to: index)
        apply(order: ids, to: columns)
        try environment.save()
    }

    // MARK: Custom fields

    @discardableResult
    public func addCustomField(
        to project: Project,
        name: String,
        type: CustomFieldType,
        options: [String] = [],
        isRequired: Bool = false
    ) throws -> CustomFieldDefinition {
        let cleanOptions = Self.cleanOptions(options)
        if type.requiresOptions, cleanOptions.isEmpty {
            throw ProjectsError.customFieldNeedsOptions
        }
        let order = (project.customFields ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let field = CustomFieldDefinition(
            name: try Validation.name(name, field: .customFieldName, maxLength: 40),
            type: type,
            options: type.requiresOptions ? cleanOptions : [],
            isRequired: isRequired,
            order: order
        )
        environment.context.insert(field)
        field.project = project
        try environment.save()
        return field
    }

    /// Updates a field definition. Values that no longer match a removed choice are cleared.
    public func updateCustomField(_ field: CustomFieldDefinition, name: String, options: [String], isRequired: Bool) throws {
        let cleanOptions = Self.cleanOptions(options)
        if field.type.requiresOptions, cleanOptions.isEmpty {
            throw ProjectsError.customFieldNeedsOptions
        }
        field.name = try Validation.name(name, field: .customFieldName, maxLength: 40)
        field.isRequired = isRequired
        var changed: [TaskItem] = []
        if field.type.requiresOptions {
            field.options = cleanOptions
            for value in field.values ?? [] where !value.value.isEmpty && !cleanOptions.contains(value.value) {
                value.value = ""
                if let task = value.task { changed.append(task) }
            }
        }
        try environment.save(changed: changed)
    }

    public func deleteCustomField(_ field: CustomFieldDefinition) throws {
        let affected = (field.values ?? []).compactMap(\.task)
        environment.context.delete(field)
        try environment.save(changed: affected)
    }

    public func moveCustomFields(in project: Project, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let fields = project.sortedCustomFields
        let ids = OrderedMove.move(fields.map(\.id), fromOffsets: source, toOffset: destination)
        let byID = Dictionary(uniqueKeysWithValues: fields.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.order = index
        }
        try environment.save()
    }

    // MARK: Helpers

    private func apply(order ids: [UUID], to columns: [BoardColumn]) {
        let byID = Dictionary(uniqueKeysWithValues: columns.map { ($0.id, $0) })
        for (index, id) in ids.enumerated() {
            byID[id]?.order = index
        }
    }

    static func cleanOptions(_ options: [String]) -> [String] {
        var seen: Set<String> = []
        return options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
