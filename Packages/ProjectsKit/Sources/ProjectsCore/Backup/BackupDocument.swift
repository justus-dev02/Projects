import Foundation

/// The versioned, app-independent JSON representation of all user data.
///
/// The format is deliberately decoupled from the SwiftData schema: the schema may evolve through
/// migrations while old backups stay readable. Bump ``currentVersion`` whenever a field changes
/// meaning, and keep decoding older versions.
public struct BackupDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var workspaces: [WorkspaceRecord]

    public init(formatVersion: Int = BackupDocument.currentVersion, exportedAt: Date, workspaces: [WorkspaceRecord]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.workspaces = workspaces
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Decodes a backup and verifies its version.
    /// - Throws: ``ProjectsError/unsupportedBackupVersion(_:)`` or ``ProjectsError/corruptBackup``.
    public static func decode(from data: Data) throws -> BackupDocument {
        struct VersionProbe: Decodable { let formatVersion: Int }
        let decoder = makeDecoder()
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else {
            throw ProjectsError.corruptBackup
        }
        guard probe.formatVersion <= currentVersion else {
            throw ProjectsError.unsupportedBackupVersion(probe.formatVersion)
        }
        do {
            return try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw ProjectsError.corruptBackup
        }
    }

    public func encoded() throws -> Data {
        try Self.makeEncoder().encode(self)
    }
}

extension BackupDocument {
    public struct WorkspaceRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var details: String
        public var colorHex: String
        public var symbolName: String
        public var isArchived: Bool
        public var createdAt: Date
        public var labels: [LabelRecord]
        public var templates: [TemplateRecord]
        public var projects: [ProjectRecord]

        public init(
            id: UUID, name: String, details: String, colorHex: String, symbolName: String,
            isArchived: Bool, createdAt: Date, labels: [LabelRecord], templates: [TemplateRecord],
            projects: [ProjectRecord]
        ) {
            self.id = id
            self.name = name
            self.details = details
            self.colorHex = colorHex
            self.symbolName = symbolName
            self.isArchived = isArchived
            self.createdAt = createdAt
            self.labels = labels
            self.templates = templates
            self.projects = projects
        }
    }

    public struct LabelRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var colorHex: String
        public var order: Int

        public init(id: UUID, name: String, colorHex: String, order: Int) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.order = order
        }
    }

    public struct TemplateRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var category: TemplateCategory
        public var taskTitle: String
        public var taskDetails: String
        public var priority: TaskPriority
        public var estimatedHours: Double?
        public var subtaskTitles: [String]
        public var usageCount: Int

        public init(
            id: UUID, name: String, category: TemplateCategory, taskTitle: String, taskDetails: String,
            priority: TaskPriority, estimatedHours: Double?, subtaskTitles: [String], usageCount: Int
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.taskTitle = taskTitle
            self.taskDetails = taskDetails
            self.priority = priority
            self.estimatedHours = estimatedHours
            self.subtaskTitles = subtaskTitles
            self.usageCount = usageCount
        }
    }

    public struct ProjectRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var details: String
        public var colorHex: String
        public var symbolName: String
        public var status: ProjectStatus
        public var isArchived: Bool
        public var startDate: Date?
        public var dueDate: Date?
        public var createdAt: Date
        public var columns: [ColumnRecord]
        public var customFields: [CustomFieldRecord]
        public var tasks: [TaskRecord]

        public init(
            id: UUID, name: String, details: String, colorHex: String, symbolName: String,
            status: ProjectStatus, isArchived: Bool, startDate: Date?, dueDate: Date?, createdAt: Date,
            columns: [ColumnRecord], customFields: [CustomFieldRecord], tasks: [TaskRecord]
        ) {
            self.id = id
            self.name = name
            self.details = details
            self.colorHex = colorHex
            self.symbolName = symbolName
            self.status = status
            self.isArchived = isArchived
            self.startDate = startDate
            self.dueDate = dueDate
            self.createdAt = createdAt
            self.columns = columns
            self.customFields = customFields
            self.tasks = tasks
        }
    }

    public struct ColumnRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var colorHex: String
        public var order: Int
        public var status: TaskStatus

        public init(id: UUID, name: String, colorHex: String, order: Int, status: TaskStatus) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.order = order
            self.status = status
        }
    }

    public struct CustomFieldRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var type: CustomFieldType
        public var options: [String]
        public var isRequired: Bool
        public var order: Int

        public init(id: UUID, name: String, type: CustomFieldType, options: [String], isRequired: Bool, order: Int) {
            self.id = id
            self.name = name
            self.type = type
            self.options = options
            self.isRequired = isRequired
            self.order = order
        }
    }

    public struct TaskRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var title: String
        public var details: String
        public var status: TaskStatus
        public var priority: TaskPriority
        public var columnID: UUID?
        public var order: Int
        public var startDate: Date?
        public var dueDate: Date?
        public var completedAt: Date?
        public var reminderDate: Date?
        public var estimatedHours: Double?
        public var recurrence: RecurrenceRule?
        public var createdAt: Date
        public var updatedAt: Date
        public var labelIDs: [UUID]
        public var blockedByIDs: [UUID]
        public var subtasks: [SubtaskRecord]
        public var comments: [CommentRecord]
        public var customFieldValues: [CustomFieldValueRecord]
        /// Added after format version 1 was released; optional so older backups still decode.
        public var involvedPeople: [String]?
        public var questions: [QuestionRecord]?

        public init(
            id: UUID, title: String, details: String, status: TaskStatus, priority: TaskPriority,
            columnID: UUID?, order: Int, startDate: Date?, dueDate: Date?, completedAt: Date?,
            reminderDate: Date?, estimatedHours: Double?, recurrence: RecurrenceRule?, createdAt: Date,
            updatedAt: Date, labelIDs: [UUID], blockedByIDs: [UUID], subtasks: [SubtaskRecord],
            comments: [CommentRecord], customFieldValues: [CustomFieldValueRecord],
            involvedPeople: [String]? = nil, questions: [QuestionRecord]? = nil
        ) {
            self.id = id
            self.title = title
            self.details = details
            self.status = status
            self.priority = priority
            self.columnID = columnID
            self.order = order
            self.startDate = startDate
            self.dueDate = dueDate
            self.completedAt = completedAt
            self.reminderDate = reminderDate
            self.estimatedHours = estimatedHours
            self.recurrence = recurrence
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.labelIDs = labelIDs
            self.blockedByIDs = blockedByIDs
            self.subtasks = subtasks
            self.comments = comments
            self.customFieldValues = customFieldValues
            self.involvedPeople = involvedPeople
            self.questions = questions
        }
    }

    public struct SubtaskRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var title: String
        public var isCompleted: Bool
        public var order: Int

        public init(id: UUID, title: String, isCompleted: Bool, order: Int) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.order = order
        }
    }

    public struct CommentRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var text: String
        public var createdAt: Date
        public var updatedAt: Date
        /// Optional for backups written before these fields existed.
        public var authorDeviceID: String?
        public var isRead: Bool?

        public init(id: UUID, text: String, createdAt: Date, updatedAt: Date, authorDeviceID: String? = nil, isRead: Bool? = nil) {
            self.id = id
            self.text = text
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.authorDeviceID = authorDeviceID
            self.isRead = isRead
        }
    }

    public struct QuestionRecord: Codable, Equatable, Sendable {
        public var id: UUID
        public var text: String
        public var isAnswered: Bool
        public var answeredAt: Date?
        public var order: Int
        public var createdAt: Date

        public init(id: UUID, text: String, isAnswered: Bool, answeredAt: Date?, order: Int, createdAt: Date) {
            self.id = id
            self.text = text
            self.isAnswered = isAnswered
            self.answeredAt = answeredAt
            self.order = order
            self.createdAt = createdAt
        }
    }

    public struct CustomFieldValueRecord: Codable, Equatable, Sendable {
        public var fieldID: UUID
        public var value: String

        public init(fieldID: UUID, value: String) {
            self.fieldID = fieldID
            self.value = value
        }
    }
}
