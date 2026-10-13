import Foundation
import SwiftData
import ProjectsCore

/// Exports all data to a ``BackupDocument`` and restores it again.
///
/// Attachments are not part of the JSON backup on purpose: they can be large binary files and
/// are already protected by iCloud sync. The UI states this explicitly.
public final class BackupService {
    public enum ImportMode: Sendable {
        /// Adds workspaces from the backup. Workspaces whose identifier already exists are skipped.
        case merge
        /// Deletes all existing data before importing.
        case replaceAll
    }

    public struct ImportSummary: Equatable, Sendable {
        public var importedWorkspaces = 0
        public var skippedWorkspaces = 0
        public var importedProjects = 0
        public var importedTasks = 0
    }

    private let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    private var context: ModelContext { environment.context }

    // MARK: Export

    public func makeBackup() throws -> BackupDocument {
        let workspaces = try environment.fetch(FetchDescriptor<Workspace>())
            .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
        return BackupDocument(exportedAt: environment.now(), workspaces: workspaces.map(record(for:)))
    }

    public func exportJSON() throws -> Data {
        do {
            return try makeBackup().encoded()
        } catch let error as ProjectsError {
            throw error
        } catch {
            Log.backup.error("Encoding backup failed: \(String(describing: error), privacy: .public)")
            throw ProjectsError.persistenceFailed
        }
    }

    private func record(for workspace: Workspace) -> BackupDocument.WorkspaceRecord {
        BackupDocument.WorkspaceRecord(
            id: workspace.id,
            name: workspace.name,
            details: workspace.details,
            colorHex: workspace.colorHex,
            symbolName: workspace.symbolName,
            isArchived: workspace.isArchived,
            createdAt: workspace.createdAt,
            labels: workspace.sortedLabels.map {
                .init(id: $0.id, name: $0.name, colorHex: $0.colorHex, order: $0.order)
            },
            templates: workspace.sortedTemplates.map {
                .init(
                    id: $0.id, name: $0.name, category: $0.category, taskTitle: $0.taskTitle,
                    taskDetails: $0.taskDetails, priority: $0.priority, estimatedHours: $0.estimatedHours,
                    subtaskTitles: $0.subtaskTitles, usageCount: $0.usageCount
                )
            },
            projects: workspace.projectList.map(record(for:))
        )
    }

    private func record(for project: Project) -> BackupDocument.ProjectRecord {
        BackupDocument.ProjectRecord(
            id: project.id,
            name: project.name,
            details: project.details,
            colorHex: project.colorHex,
            symbolName: project.symbolName,
            status: project.status,
            isArchived: project.isArchived,
            startDate: project.startDate,
            dueDate: project.dueDate,
            createdAt: project.createdAt,
            columns: project.sortedColumns.map {
                .init(id: $0.id, name: $0.name, colorHex: $0.colorHex, order: $0.order, status: $0.status)
            },
            customFields: project.sortedCustomFields.map {
                .init(id: $0.id, name: $0.name, type: $0.type, options: $0.options, isRequired: $0.isRequired, order: $0.order)
            },
            tasks: project.taskList.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }.map(\.backupRecord)
        )
    }

    // MARK: Import

    @discardableResult
    public func importJSON(_ data: Data, mode: ImportMode) throws -> ImportSummary {
        try restore(BackupDocument.decode(from: data), mode: mode)
    }

    @discardableResult
    public func restore(_ document: BackupDocument, mode: ImportMode) throws -> ImportSummary {
        var deletedTaskIDs: [UUID] = []
        if mode == .replaceAll {
            let existing = try environment.fetch(FetchDescriptor<Workspace>())
            deletedTaskIDs = existing.flatMap(\.projectList).flatMap(\.taskList).map(\.id)
            for workspace in existing {
                context.delete(workspace)
            }
        }

        let existingIDs = Set(try environment.fetch(FetchDescriptor<Workspace>()).map(\.id))
        var summary = ImportSummary()
        var importedTasks: [TaskItem] = []

        for record in document.workspaces {
            if mode == .merge, existingIDs.contains(record.id) {
                summary.skippedWorkspaces += 1
                continue
            }
            let tasks = insert(record, summary: &summary)
            importedTasks.append(contentsOf: tasks)
            summary.importedWorkspaces += 1
        }

        do {
            try environment.save(changed: importedTasks, deleted: deletedTaskIDs)
        } catch {
            Log.backup.error("Saving the restored backup failed")
            throw error
        }
        Log.backup.notice("Backup restored: \(summary.importedWorkspaces) workspaces, \(summary.importedTasks) tasks")
        return summary
    }

    private func insert(_ record: BackupDocument.WorkspaceRecord, summary: inout ImportSummary) -> [TaskItem] {
        let workspace = Workspace(name: record.name, details: record.details, colorHex: record.colorHex, symbolName: record.symbolName)
        workspace.id = record.id
        workspace.isArchived = record.isArchived
        workspace.createdAt = record.createdAt
        context.insert(workspace)

        var labels: [UUID: TaskLabel] = [:]
        for labelRecord in record.labels {
            let label = TaskLabel(name: labelRecord.name, colorHex: labelRecord.colorHex, order: labelRecord.order)
            label.id = labelRecord.id
            context.insert(label)
            label.workspace = workspace
            labels[label.id] = label
        }

        for templateRecord in record.templates {
            let template = TaskTemplate(name: templateRecord.name, category: templateRecord.category, taskTitle: templateRecord.taskTitle)
            template.id = templateRecord.id
            template.taskDetails = templateRecord.taskDetails
            template.priority = templateRecord.priority
            template.estimatedHours = templateRecord.estimatedHours
            template.subtaskTitles = templateRecord.subtaskTitles
            template.usageCount = templateRecord.usageCount
            context.insert(template)
            template.workspace = workspace
        }

        var tasks: [TaskItem] = []
        for projectRecord in record.projects {
            tasks += insert(projectRecord, into: workspace, labels: labels)
            summary.importedProjects += 1
        }
        summary.importedTasks += tasks.count
        return tasks
    }

    private func insert(_ record: BackupDocument.ProjectRecord, into workspace: Workspace, labels: [UUID: TaskLabel]) -> [TaskItem] {
        let project = Project(name: record.name, details: record.details, colorHex: record.colorHex, symbolName: record.symbolName)
        project.id = record.id
        project.status = record.status
        project.isArchived = record.isArchived
        project.startDate = record.startDate
        project.dueDate = record.dueDate
        project.createdAt = record.createdAt
        context.insert(project)
        project.workspace = workspace

        var columns: [UUID: BoardColumn] = [:]
        var orderedColumns: [BoardColumn] = []
        for columnRecord in record.columns.sorted(by: { $0.order < $1.order }) {
            let column = BoardColumn(name: columnRecord.name, status: columnRecord.status, colorHex: columnRecord.colorHex, order: orderedColumns.count)
            column.id = columnRecord.id
            context.insert(column)
            column.project = project
            columns[column.id] = column
            orderedColumns.append(column)
        }
        if orderedColumns.isEmpty {
            // A board without columns is unusable; recreate a single column.
            let column = BoardColumn(name: TaskStatus.todo.title, status: .todo)
            context.insert(column)
            column.project = project
            orderedColumns.append(column)
        }

        var fields: [UUID: CustomFieldDefinition] = [:]
        for fieldRecord in record.customFields {
            let field = CustomFieldDefinition(
                name: fieldRecord.name, type: fieldRecord.type, options: fieldRecord.options,
                isRequired: fieldRecord.isRequired, order: fieldRecord.order
            )
            field.id = fieldRecord.id
            context.insert(field)
            field.project = project
            fields[field.id] = field
        }

        var tasks: [UUID: TaskItem] = [:]
        for taskRecord in record.tasks {
            let task = insert(taskRecord, into: project, columns: columns, orderedColumns: orderedColumns, labels: labels, fields: fields)
            tasks[task.id] = task
        }

        // Dependencies are wired in a second pass because they reference other tasks.
        for taskRecord in record.tasks {
            guard let task = tasks[taskRecord.id] else { continue }
            task.blockedBy = taskRecord.blockedByIDs.compactMap { id in id == task.id ? nil : tasks[id] }
        }
        return Array(tasks.values)
    }

    // swiftlint:disable:next function_parameter_count
    private func insert(
        _ taskRecord: BackupDocument.TaskRecord,
        into project: Project,
        columns: [UUID: BoardColumn],
        orderedColumns: [BoardColumn],
        labels: [UUID: TaskLabel],
        fields: [UUID: CustomFieldDefinition]
    ) -> TaskItem {
        let task = TaskItem(title: taskRecord.title, details: taskRecord.details, status: taskRecord.status, priority: taskRecord.priority)
        task.id = taskRecord.id
        task.order = taskRecord.order
        task.startDate = taskRecord.startDate
        task.dueDate = taskRecord.dueDate
        task.completedAt = taskRecord.completedAt
        task.reminderDate = taskRecord.reminderDate
        task.estimatedHours = taskRecord.estimatedHours
        task.recurrence = taskRecord.recurrence
        task.createdAt = taskRecord.createdAt
        task.updatedAt = taskRecord.updatedAt
        context.insert(task)
        task.project = project
        // Unknown column references fall back to a column with the same status.
        task.column = taskRecord.columnID.flatMap { columns[$0] }
            ?? orderedColumns.first { $0.status == taskRecord.status }
            ?? orderedColumns.first
        task.labels = taskRecord.labelIDs.compactMap { labels[$0] }

        for subtaskRecord in taskRecord.subtasks {
            let subtask = Subtask(title: subtaskRecord.title, order: subtaskRecord.order)
            subtask.id = subtaskRecord.id
            subtask.isCompleted = subtaskRecord.isCompleted
            context.insert(subtask)
            subtask.task = task
        }
        task.restoreChildren(from: taskRecord, in: context)
        for valueRecord in taskRecord.customFieldValues {
            guard let field = fields[valueRecord.fieldID] else { continue }
            let value = CustomFieldValue(value: valueRecord.value)
            context.insert(value)
            value.definition = field
            value.task = task
        }
        return task
    }
}
