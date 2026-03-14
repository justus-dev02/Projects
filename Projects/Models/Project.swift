//
//  Project.swift
//  Projects
//
//  TaskFlow - Project Model
//

import Foundation
import SwiftData
import Combine

@Model
final class Project {
    @Attribute(.unique) var id: String
    var name: String
    var projectDescription: String?
    var color: String
    var icon: String
    var status: String
    var isArchived: Bool
    var startDate: Date?
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var tasks: [Task]?
    @Relationship(deleteRule: .cascade) var boardColumns: [BoardColumn]?
    @Relationship(deleteRule: .nullify) var workspace: Workspace?
    @Relationship(deleteRule: .cascade) var members: [ProjectMember]?

    // New relationships for advanced features
    @Relationship(deleteRule: .cascade) var customFieldDefinitions: [CustomFieldDefinition]?
    @Relationship(deleteRule: .cascade) var templates: [TaskTemplate]?
    @Relationship(deleteRule: .cascade) var invitations: [Invitation]?
    @Relationship(deleteRule: .cascade) var savedViews: [SavedView]?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        projectDescription: String? = nil,
        color: String = "#4ECDC4",
        icon: String = "folder.fill",
        status: String = "active",
        isArchived: Bool = false,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.color = color
        self.icon = icon
        self.status = status
        self.isArchived = isArchived
        self.startDate = startDate
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Project Member
@Model
final class ProjectMember {
    @Attribute(.unique) var id: String
    var joinedAt: Date
    var role: String
    
    // Relationships
    @Relationship(deleteRule: .cascade) var user: User?
    @Relationship(deleteRule: .cascade) var project: Project?
    
    init(
        id: String = UUID().uuidString,
        joinedAt: Date = Date(),
        role: String = "member"
    ) {
        self.id = id
        self.joinedAt = joinedAt
        self.role = role
    }
}

// MARK: - Board Column (Kanban)
@Model
final class BoardColumn {
    @Attribute(.unique) var id: String
    var name: String
    var color: String
    var order: Int
    var isCollapsed: Bool
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var tasks: [Task]?
    @Relationship(deleteRule: .nullify) var project: Project?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "#E6E9ED",
        order: Int = 0,
        isCollapsed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.order = order
        self.isCollapsed = isCollapsed
        self.createdAt = createdAt
    }
}

// MARK: - Project Status Extension
extension Project {
    enum Status: String, CaseIterable, Identifiable {
        case active = "Active"
        case paused = "Paused"
        case completed = "Completed"
        case archived = "Archived"
        
        var id: String { rawValue }
        
        var color: String {
            switch self {
            case .active: return "#00BA88"
            case .paused: return "#FFB020"
            case .completed: return "#2D5BFF"
            case .archived: return "#95A5A6"
            }
        }
        
        var icon: String {
            switch self {
            case .active: return "play.circle.fill"
            case .paused: return "pause.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .archived: return "archivebox.fill"
            }
        }
    }
    
    var taskCount: Int {
        tasks?.count ?? 0
    }
    
    var completedTaskCount: Int {
        tasks?.filter { $0.status == "done" }.count ?? 0
    }
    
    var progressPercentage: Double {
        guard taskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(taskCount) * 100
    }
}

// MARK: - Default Board Columns
extension BoardColumn {
    static func defaultColumns() -> [BoardColumn] {
        [
            BoardColumn(name: "To Do", color: "#FF6B6B", order: 0),
            BoardColumn(name: "In Progress", color: "#FFB020", order: 1),
            BoardColumn(name: "Review", color: "#45B7D1", order: 2),
            BoardColumn(name: "Done", color: "#00BA88", order: 3)
        ]
    }
}
