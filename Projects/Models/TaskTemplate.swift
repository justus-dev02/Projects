//
//  TaskTemplate.swift
//  Projects
//
//  TaskFlow - Task Template Model
//

import Foundation
import SwiftData

/// Model for reusable task templates
@Model
final class TaskTemplate {
    @Attribute(.unique) var id: String
    var name: String
    var templateDescription: String?
    var category: String
    var icon: String
    var color: String
    var isPublic: Bool
    var usageCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    // Template Content
    var title: String
    var taskDescription: String?
    var priority: String
    var estimatedHours: Double?
    var labels: String?  // JSON array of label IDs
    var subtasks: String?  // JSON array of subtask titles
    var checklists: String?  // JSON array of checklist items
    
    // Relationships
    @Relationship(deleteRule: .nullify) var project: Project?
    @Relationship(deleteRule: .nullify) var workspace: Workspace?
    @Relationship(deleteRule: .nullify) var createdBy: User?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        templateDescription: String? = nil,
        category: String = "General",
        icon: String = "doc.text",
        color: String = "#2D5BFF",
        isPublic: Bool = false,
        usageCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String = "",
        taskDescription: String? = nil,
        priority: String = "medium",
        estimatedHours: Double? = nil,
        labels: String? = nil,
        subtasks: String? = nil,
        checklists: String? = nil
    ) {
        self.id = id
        self.name = name
        self.templateDescription = templateDescription
        self.category = category
        self.icon = icon
        self.color = color
        self.isPublic = isPublic
        self.usageCount = usageCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.taskDescription = taskDescription
        self.priority = priority
        self.estimatedHours = estimatedHours
        self.labels = labels
        self.subtasks = subtasks
        self.checklists = checklists
    }
}

// MARK: - Template Category
extension TaskTemplate {
    enum TemplateCategory: String, CaseIterable, Identifiable {
        case general = "General"
        case bug = "Bug"
        case feature = "Feature"
        case meeting = "Meeting"
        case review = "Review"
        case documentation = "Documentation"
        case testing = "Testing"
        case design = "Design"
        case research = "Research"
        case marketing = "Marketing"
        case development = "Development"
        case onboarding = "Onboarding"
        case maintenance = "Maintenance"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "folder"
            case .bug: return "ladybug.fill"
            case .feature: return "star.fill"
            case .meeting: return "person.2.fill"
            case .review: return "eye.fill"
            case .documentation: return "doc.text.fill"
            case .testing: return "checkmark.seal.fill"
            case .design: return "paintbrush.fill"
            case .research: return "magnifyingglass"
            case .marketing: return "megaphone.fill"
            case .development: return "chevron.left.slash.chevron.right"
            case .onboarding: return "person.badge.plus"
            case .maintenance: return "wrench.fill"
            }
        }
        
        var color: String {
            switch self {
            case .general: return "#95A5A6"
            case .bug: return "#FF4757"
            case .feature: return "#2D5BFF"
            case .meeting: return "#FF6B6B"
            case .review: return "#FFB020"
            case .documentation: return "#95A5A6"
            case .testing: return "#00BA88"
            case .design: return "#A855F7"
            case .research: return "#45B7D1"
            case .marketing: return "#FF6B6B"
            case .development: return "#4ECDC4"
            case .onboarding: return "#00BA88"
            case .maintenance: return "#95A5A6"
            }
        }
    }
}

// MARK: - Template Data
extension TaskTemplate {
    struct SubtaskTemplate: Codable {
        let title: String
        let order: Int
    }
    
    struct ChecklistTemplate: Codable {
        let title: String
        let items: [ChecklistItemTemplate]
    }
    
    struct ChecklistItemTemplate: Codable {
        let title: String
        let order: Int
    }
    
    var parsedSubtasks: [SubtaskTemplate]? {
        guard let subtasks = subtasks else { return nil }
        guard let data = subtasks.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([SubtaskTemplate].self, from: data)
    }
    
    var parsedChecklists: [ChecklistTemplate]? {
        guard let checklists = checklists else { return nil }
        guard let data = checklists.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([ChecklistTemplate].self, from: data)
    }
    
    var parsedLabels: [String]? {
        guard let labels = labels else { return nil }
        guard let data = labels.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
}

// MARK: - Task Creation from Template
extension TaskTemplate {
    func createTask(
        in project: Project,
        column: BoardColumn,
        assignee: User? = nil,
        dueDate: Date? = nil,
        customTitle: String? = nil
    ) -> Task {
        let task = Task(
            title: customTitle ?? title,
            taskDescription: taskDescription,
            priority: priority,
            dueDate: dueDate,
            estimatedHours: estimatedHours
        )
        task.column = column
        task.project = project
        task.assignee = assignee
        
        // Create subtasks from template
        if let subtaskTemplates = parsedSubtasks {
            for (index, subtaskTemplate) in subtaskTemplates.enumerated() {
                let subtask = Subtask(
                    title: subtaskTemplate.title,
                    order: index
                )
                subtask.task = task
                task.subtasks?.append(subtask)
            }
        }
        
        usageCount += 1
        
        return task
    }
}

// MARK: - Creating Template from Task
extension TaskTemplate {
    static func createFromTask(_ task: Task, name: String, category: String = "General") -> TaskTemplate {
        let subtasks = task.subtasks?.sorted(by: { $0.order < $1.order }).map { subtask in
            TaskTemplate.SubtaskTemplate(title: subtask.title, order: subtask.order)
        }
        
        let template = TaskTemplate(
            name: name,
            category: category,
            title: task.title,
            taskDescription: task.taskDescription,
            priority: task.priority,
            estimatedHours: task.estimatedHours
        )
        
        // Serialize subtasks
        if let subtasks = subtasks {
            template.subtasks = try? JSONEncoder().encodeToString(subtasks)
        }
        
        return template
    }
}

// MARK: - Helper Extension
extension JSONEncoder {
    func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
