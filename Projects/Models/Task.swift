//
//  Task.swift
//  Projects
//
//  TaskFlow - Task Model
//

import Foundation
import SwiftData

@Model
final class Task {
    @Attribute(.unique) var id: String
    var title: String
    var taskDescription: String?
    var status: String
    var priority: String
    var order: Int
    var dueDate: Date?
    var completedAt: Date?
    var estimatedHours: Double?
    var actualHours: Double?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify) var column: BoardColumn?
    @Relationship(deleteRule: .nullify) var project: Project?
    @Relationship(deleteRule: .nullify) var assignee: User?
    @Relationship(deleteRule: .cascade) var subtasks: [Subtask]?
    @Relationship(deleteRule: .cascade) var comments: [Comment]?
    @Relationship(deleteRule: .cascade) var attachments: [Attachment]?
    @Relationship(deleteRule: .cascade) var labels: [TaskLabel]?
    @Relationship(deleteRule: .cascade) var activityLogs: [ActivityLog]?
    @Relationship(deleteRule: .nullify) var collaborators: [TaskCollaborator]?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        taskDescription: String? = nil,
        status: String = "todo",
        priority: String = "medium",
        order: Int = 0,
        dueDate: Date? = nil,
        completedAt: Date? = nil,
        estimatedHours: Double? = nil,
        actualHours: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.status = status
        self.priority = priority
        self.order = order
        self.dueDate = dueDate
        self.completedAt = completedAt
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Subtask
@Model
final class Subtask {
    @Attribute(.unique) var id: String
    var title: String
    var isCompleted: Bool
    var order: Int
    var completedAt: Date?
    var createdAt: Date
    
    // Relationship
    @Relationship(deleteRule: .cascade) var task: Task?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        isCompleted: Bool = false,
        order: Int = 0,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.order = order
        self.completedAt = completedAt
        self.createdAt = createdAt
    }
}

// MARK: - Comment
@Model
final class Comment {
    @Attribute(.unique) var id: String
    var content: String
    var isEdited: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var author: User?
    @Relationship(deleteRule: .cascade) var task: Task?
    
    init(
        id: String = UUID().uuidString,
        content: String,
        isEdited: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.content = content
        self.isEdited = isEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Attachment
@Model
final class Attachment {
    @Attribute(.unique) var id: String
    var fileName: String
    var fileSize: Int64
    var mimeType: String
    var url: String?
    var thumbnailUrl: String?
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var uploader: User?
    @Relationship(deleteRule: .cascade) var task: Task?
    
    init(
        id: String = UUID().uuidString,
        fileName: String,
        fileSize: Int64,
        mimeType: String,
        url: String? = nil,
        thumbnailUrl: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.createdAt = createdAt
    }
}

// MARK: - Task Label (Junction)
@Model
final class TaskLabel {
    @Attribute(.unique) var id: String
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var task: Task?
    @Relationship(deleteRule: .cascade) var label: Label?
    
    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.createdAt = createdAt
    }
}

// MARK: - Task Collaborator (Junction)
@Model
final class TaskCollaborator {
    @Attribute(.unique) var id: String
    var role: String
    var joinedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var task: Task?
    @Relationship(deleteRule: .cascade) var user: User?
    
    init(
        id: String = UUID().uuidString,
        role: String = "contributor",
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.joinedAt = joinedAt
    }
}

// MARK: - Activity Log
@Model
final class ActivityLog {
    @Attribute(.unique) var id: String
    var action: String
    var logDescription: String
    var metadata: String?
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .nullify) var user: User?
    @Relationship(deleteRule: .cascade) var task: Task?

    init(
        id: String = UUID().uuidString,
        action: String,
        logDescription: String,
        metadata: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.action = action
        self.logDescription = logDescription
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

// MARK: - Task Status Extension
extension Task {
    enum Status: String, CaseIterable, Identifiable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case review = "Review"
        case done = "Done"
        
        var id: String { rawValue }
        
        var color: String {
            switch self {
            case .todo: return "#95A5A6"
            case .inProgress: return "#45B7D1"
            case .review: return "#FFB020"
            case .done: return "#00BA88"
            }
        }
        
        var icon: String {
            switch self {
            case .todo: return "circle"
            case .inProgress: return "arrow.triangle.2.circlepath"
            case .review: return "eye.fill"
            case .done: return "checkmark.circle.fill"
            }
        }
    }
}

// MARK: - Task Priority Extension
extension Task {
    enum Priority: String, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
        
        var id: String { rawValue }
        
        var color: String {
            switch self {
            case .low: return "#95A5A6"
            case .medium: return "#45B7D1"
            case .high: return "#FFB020"
            case .urgent: return "#FF4757"
            }
        }
        
        var icon: String {
            switch self {
            case .low: return "arrow.down"
            case .medium: return "arrow.left.and.right"
            case .high: return "arrow.up.right"
            case .urgent: return "exclamationmark.triangle.fill"
            }
        }
        
        var weight: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .urgent: return 4
            }
        }
    }
}

// MARK: - Task Computed Properties
extension Task {
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    var isCompleted: Bool {
        status == "done"
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var isDueTomorrow: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }
    
    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
    
    var subtaskProgress: Double {
        guard let subtasks = subtasks, !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(subtasks.count)
    }
    
    var commentCount: Int {
        comments?.count ?? 0
    }
    
    var attachmentCount: Int {
        attachments?.count ?? 0
    }
    
    var completedSubtaskCount: Int {
        subtasks?.filter { $0.isCompleted }.count ?? 0
    }
    
    var totalSubtaskCount: Int {
        subtasks?.count ?? 0
    }
}
