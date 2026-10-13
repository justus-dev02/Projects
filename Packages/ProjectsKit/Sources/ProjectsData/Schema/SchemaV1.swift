import Foundation
import SwiftData
import ProjectsCore

/// Version 1 of the persisted schema.
///
/// Rules that keep the schema compatible with iCloud sync (`NSPersistentCloudKitContainer`):
/// - every attribute has a default value or is optional,
/// - every relationship is optional and has an explicit inverse,
/// - no unique constraints (`id` is unique by construction, not by the store).
///
/// Delete rules always cascade from parent to child, never from child to parent.
/// Never edit a released schema version. Add `SchemaV2` and a migration stage instead
/// (see `docs/adr/0002-persistence.md`).
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            Workspace.self,
            Project.self,
            BoardColumn.self,
            TaskItem.self,
            Subtask.self,
            TaskComment.self,
            TaskAttachment.self,
            ActivityEntry.self,
            TaskLabel.self,
            CustomFieldDefinition.self,
            CustomFieldValue.self,
            TaskTemplate.self,
        ]
    }
}

extension SchemaV1 {
    @Model
    public final class Workspace {
        public var id: UUID = UUID()
        public var name: String = ""
        public var details: String = ""
        public var colorHex: String = "#5B5BD6"
        public var symbolName: String = "briefcase"
        public var isArchived: Bool = false
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        @Relationship(deleteRule: .cascade, inverse: \Project.workspace)
        public var projects: [Project]? = []

        @Relationship(deleteRule: .cascade, inverse: \TaskLabel.workspace)
        public var labels: [TaskLabel]? = []

        @Relationship(deleteRule: .cascade, inverse: \TaskTemplate.workspace)
        public var templates: [TaskTemplate]? = []

        public init(name: String, details: String = "", colorHex: String = "#5B5BD6", symbolName: String = "briefcase") {
            self.name = name
            self.details = details
            self.colorHex = colorHex
            self.symbolName = symbolName
        }
    }

    @Model
    public final class Project {
        public var id: UUID = UUID()
        public var name: String = ""
        public var details: String = ""
        public var colorHex: String = "#5B5BD6"
        public var symbolName: String = "folder"
        public var statusRaw: String = ProjectStatus.active.rawValue
        public var isArchived: Bool = false
        public var startDate: Date?
        public var dueDate: Date?
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var workspace: Workspace?

        @Relationship(deleteRule: .cascade, inverse: \BoardColumn.project)
        public var columns: [BoardColumn]? = []

        @Relationship(deleteRule: .cascade, inverse: \TaskItem.project)
        public var tasks: [TaskItem]? = []

        @Relationship(deleteRule: .cascade, inverse: \CustomFieldDefinition.project)
        public var customFields: [CustomFieldDefinition]? = []

        public init(name: String, details: String = "", colorHex: String = "#5B5BD6", symbolName: String = "folder") {
            self.name = name
            self.details = details
            self.colorHex = colorHex
            self.symbolName = symbolName
        }
    }

    /// A column of the Kanban board. Every column maps to a ``TaskStatus``: moving a task into a
    /// column sets the task's status, and changing a task's status moves it into a matching column.
    @Model
    public final class BoardColumn {
        public var id: UUID = UUID()
        public var name: String = ""
        public var colorHex: String = "#8E8E93"
        public var order: Int = 0
        public var statusRaw: String = TaskStatus.todo.rawValue
        public var createdAt: Date = Date.now

        public var project: Project?

        /// Deleting a column must not delete its tasks; `ProjectService.deleteColumn` moves them first.
        @Relationship(deleteRule: .nullify, inverse: \TaskItem.column)
        public var tasks: [TaskItem]? = []

        public init(name: String, status: TaskStatus, colorHex: String = "#8E8E93", order: Int = 0) {
            self.name = name
            self.statusRaw = status.rawValue
            self.colorHex = colorHex
            self.order = order
        }
    }

    @Model
    public final class TaskItem {
        public var id: UUID = UUID()
        public var title: String = ""
        public var details: String = ""
        public var statusRaw: String = TaskStatus.todo.rawValue
        public var priorityRaw: Int = TaskPriority.medium.rawValue
        public var order: Int = 0
        public var startDate: Date?
        public var dueDate: Date?
        public var completedAt: Date?
        public var reminderDate: Date?
        public var estimatedHours: Double?
        public var recurrence: RecurrenceRule?
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var project: Project?
        public var column: BoardColumn?

        @Relationship(deleteRule: .cascade, inverse: \Subtask.task)
        public var subtasks: [Subtask]? = []

        @Relationship(deleteRule: .cascade, inverse: \TaskComment.task)
        public var comments: [TaskComment]? = []

        @Relationship(deleteRule: .cascade, inverse: \TaskAttachment.task)
        public var attachments: [TaskAttachment]? = []

        @Relationship(deleteRule: .cascade, inverse: \ActivityEntry.task)
        public var activity: [ActivityEntry]? = []

        @Relationship(deleteRule: .cascade, inverse: \CustomFieldValue.task)
        public var customFieldValues: [CustomFieldValue]? = []

        /// Many-to-many. Deleting a task only removes it from the label, never the label itself.
        @Relationship(deleteRule: .nullify, inverse: \TaskLabel.tasks)
        public var labels: [TaskLabel]? = []

        /// Tasks that have to be finished before this one can start.
        @Relationship(deleteRule: .nullify, inverse: \TaskItem.blocking)
        public var blockedBy: [TaskItem]? = []

        /// Tasks that wait for this one. Inverse of ``blockedBy``.
        @Relationship(deleteRule: .nullify)
        public var blocking: [TaskItem]? = []

        public init(title: String, details: String = "", status: TaskStatus = .todo, priority: TaskPriority = .medium) {
            self.title = title
            self.details = details
            self.statusRaw = status.rawValue
            self.priorityRaw = priority.rawValue
        }
    }

    @Model
    public final class Subtask {
        public var id: UUID = UUID()
        public var title: String = ""
        public var isCompleted: Bool = false
        public var order: Int = 0
        public var completedAt: Date?
        public var createdAt: Date = Date.now

        public var task: TaskItem?

        public init(title: String, order: Int = 0) {
            self.title = title
            self.order = order
        }
    }

    @Model
    public final class TaskComment {
        public var id: UUID = UUID()
        public var text: String = ""
        public var createdAt: Date = Date.now
        public var updatedAt: Date = Date.now

        public var task: TaskItem?

        public init(text: String) {
            self.text = text
        }
    }

    /// File content lives in external storage (and as a CKAsset when synced), not inline in SQLite.
    @Model
    public final class TaskAttachment {
        public var id: UUID = UUID()
        public var fileName: String = ""
        /// Uniform type identifier, e.g. `public.png`.
        public var contentType: String = "public.data"
        public var byteCount: Int = 0
        @Attribute(.externalStorage)
        public var data: Data?
        public var createdAt: Date = Date.now

        public var task: TaskItem?

        public init(fileName: String, contentType: String, data: Data) {
            self.fileName = fileName
            self.contentType = contentType
            self.byteCount = data.count
            self.data = data
        }
    }

    @Model
    public final class ActivityEntry {
        public var id: UUID = UUID()
        public var kindRaw: String = ActivityKind.created.rawValue
        public var detail: String?
        public var createdAt: Date = Date.now

        public var task: TaskItem?

        public init(kind: ActivityKind, detail: String? = nil, createdAt: Date) {
            self.kindRaw = kind.rawValue
            self.detail = detail
            self.createdAt = createdAt
        }
    }

    @Model
    public final class TaskLabel {
        public var id: UUID = UUID()
        public var name: String = ""
        public var colorHex: String = "#5B5BD6"
        public var order: Int = 0

        public var workspace: Workspace?
        public var tasks: [TaskItem]? = []

        public init(name: String, colorHex: String, order: Int = 0) {
            self.name = name
            self.colorHex = colorHex
            self.order = order
        }
    }

    @Model
    public final class CustomFieldDefinition {
        public var id: UUID = UUID()
        public var name: String = ""
        public var typeRaw: String = CustomFieldType.text.rawValue
        public var options: [String] = []
        public var isRequired: Bool = false
        public var order: Int = 0

        public var project: Project?

        @Relationship(deleteRule: .cascade, inverse: \CustomFieldValue.definition)
        public var values: [CustomFieldValue]? = []

        public init(name: String, type: CustomFieldType, options: [String] = [], isRequired: Bool = false, order: Int = 0) {
            self.name = name
            self.typeRaw = type.rawValue
            self.options = options
            self.isRequired = isRequired
            self.order = order
        }
    }

    @Model
    public final class CustomFieldValue {
        public var id: UUID = UUID()
        /// Normalised by `CustomFieldCodec`.
        public var value: String = ""

        public var definition: CustomFieldDefinition?
        public var task: TaskItem?

        public init(value: String) {
            self.value = value
        }
    }

    @Model
    public final class TaskTemplate {
        public var id: UUID = UUID()
        public var name: String = ""
        public var categoryRaw: String = TemplateCategory.general.rawValue
        public var taskTitle: String = ""
        public var taskDetails: String = ""
        public var priorityRaw: Int = TaskPriority.medium.rawValue
        public var estimatedHours: Double?
        public var subtaskTitles: [String] = []
        public var usageCount: Int = 0
        public var createdAt: Date = Date.now

        public var workspace: Workspace?

        public init(name: String, category: TemplateCategory, taskTitle: String) {
            self.name = name
            self.categoryRaw = category.rawValue
            self.taskTitle = taskTitle
        }
    }
}
