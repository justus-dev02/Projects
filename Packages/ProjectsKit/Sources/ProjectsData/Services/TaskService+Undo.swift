import Foundation
import SwiftData
import ProjectsCore

/// Everything needed to bring deleted tasks back.
///
/// SwiftData's built-in undo manager crashes when undoing a deletion after the context was saved
/// ("A snapshot should exist before creating a new snapshot for undo"), so Projects implements
/// "Undo delete" explicitly. See `docs/adr/0004-undo.md`.
public struct DeletedTasks: Sendable {
    struct Attachment: Sendable {
        let id: UUID
        let fileName: String
        let contentType: String
        let data: Data
        let createdAt: Date
    }

    struct Activity: Sendable {
        let kind: String
        let detail: String?
        let createdAt: Date
    }

    struct Entry: Sendable {
        let projectID: UUID
        let record: BackupDocument.TaskRecord
        /// Tasks that were blocked by the deleted task.
        let dependentIDs: [UUID]
        let attachments: [Attachment]
        let activity: [Activity]
    }

    let entries: [Entry]

    public var count: Int { entries.count }
    public var taskIDs: [UUID] { entries.map(\.record.id) }
}

extension TaskService {
    /// Deletes tasks and returns a snapshot that ``restore(_:)`` can bring back.
    @discardableResult
    public func deleteUndoably(_ tasks: [TaskItem]) throws -> DeletedTasks {
        let entries = tasks.compactMap { task -> DeletedTasks.Entry? in
            guard let project = task.project else { return nil }
            return DeletedTasks.Entry(
                projectID: project.id,
                record: task.backupRecord,
                dependentIDs: (task.blocking ?? []).map(\.id),
                attachments: task.sortedAttachments.map {
                    .init(id: $0.id, fileName: $0.fileName, contentType: $0.contentType, data: $0.data ?? Data(), createdAt: $0.createdAt)
                },
                activity: task.sortedActivity.map { .init(kind: $0.kindRaw, detail: $0.detail, createdAt: $0.createdAt) }
            )
        }
        try delete(tasks)
        return DeletedTasks(entries: entries)
    }

    /// Re-creates previously deleted tasks with their identifiers, children, labels and
    /// dependencies. Tasks whose project was deleted in the meantime are skipped.
    /// - Returns: The restored tasks.
    @discardableResult
    public func restore(_ deleted: DeletedTasks) throws -> [TaskItem] {
        let context = environmentContext
        var restored: [UUID: TaskItem] = [:]

        for entry in deleted.entries {
            let projectID = entry.projectID
            var descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == projectID })
            descriptor.fetchLimit = 1
            guard let project = try context.fetch(descriptor).first else { continue }
            let task = insertTask(from: entry, into: project)
            restored[task.id] = task
        }

        // Second pass: dependencies may point to other restored tasks or to existing ones.
        for entry in deleted.entries {
            guard let task = restored[entry.record.id] else { continue }
            task.blockedBy = try entry.record.blockedByIDs.compactMap { try restored[$0] ?? self.task(id: $0) }
            for dependentID in entry.dependentIDs {
                guard let dependent = try restored[dependentID] ?? self.task(id: dependentID) else { continue }
                if !(dependent.blockedBy ?? []).contains(where: { $0.id == task.id }) {
                    dependent.blockedBy = (dependent.blockedBy ?? []) + [task]
                }
            }
        }

        try saveRestored(Array(restored.values))
        return Array(restored.values)
    }
    /// Inserts one deleted task with all its children. Does not save.
    private func insertTask(from entry: DeletedTasks.Entry, into project: Project) -> TaskItem {
        let context = environmentContext
        let record = entry.record
        let task = TaskItem(title: record.title, details: record.details, status: record.status, priority: record.priority)
        task.id = record.id
        task.order = record.order
        task.startDate = record.startDate
        task.dueDate = record.dueDate
        task.completedAt = record.completedAt
        task.reminderDate = record.reminderDate
        task.estimatedHours = record.estimatedHours
        task.recurrence = record.recurrence
        task.createdAt = record.createdAt
        task.updatedAt = record.updatedAt
        context.insert(task)
        task.project = project
        task.column = project.sortedColumns.first { $0.id == record.columnID }
            ?? project.firstColumn(for: record.status)
            ?? project.sortedColumns.first
        let labelIDs = Set(record.labelIDs)
        task.labels = (project.workspace?.labels ?? []).filter { labelIDs.contains($0.id) }

        for subtaskRecord in record.subtasks {
            let subtask = Subtask(title: subtaskRecord.title, order: subtaskRecord.order)
            subtask.id = subtaskRecord.id
            subtask.isCompleted = subtaskRecord.isCompleted
            context.insert(subtask)
            subtask.task = task
        }
        task.restoreChildren(from: record, in: context)
        for valueRecord in record.customFieldValues {
            guard let field = project.sortedCustomFields.first(where: { $0.id == valueRecord.fieldID }) else { continue }
            let value = CustomFieldValue(value: valueRecord.value)
            context.insert(value)
            value.definition = field
            value.task = task
        }
        for payload in entry.attachments {
            let attachment = TaskAttachment(fileName: payload.fileName, contentType: payload.contentType, data: payload.data)
            attachment.id = payload.id
            attachment.createdAt = payload.createdAt
            context.insert(attachment)
            attachment.task = task
        }
        for item in entry.activity {
            let activity = ActivityEntry(kind: ActivityKind(rawValue: item.kind) ?? .created, detail: item.detail, createdAt: item.createdAt)
            context.insert(activity)
            activity.task = task
        }
        return task
    }
}
