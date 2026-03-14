//
//  Workspace.swift
//  Projects
//
//  TaskFlow - Workspace Model
//

import Foundation
import SwiftData

@Model
final class Workspace {
    @Attribute(.unique) var id: String
    var name: String
    var workspaceDescription: String?
    var color: String
    var icon: String
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var projects: [Project]?
    @Relationship(deleteRule: .nullify) var owner: User?
    @Relationship(deleteRule: .cascade) var members: [WorkspaceMember]?
    @Relationship(deleteRule: .cascade) var labels: [Label]?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        workspaceDescription: String? = nil,
        color: String = "#2D5BFF",
        icon: String = "briefcase.fill",
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.workspaceDescription = workspaceDescription
        self.color = color
        self.icon = icon
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Workspace Member
@Model
final class WorkspaceMember {
    @Attribute(.unique) var id: String
    var joinedAt: Date
    var role: String
    
    // Relationships
    @Relationship(deleteRule: .cascade) var user: User?
    @Relationship(deleteRule: .cascade) var workspace: Workspace?
    
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

// MARK: - Workspace Stats Extension
extension Workspace {
    var projectCount: Int {
        projects?.count ?? 0
    }
    
    var memberCount: Int {
        members?.count ?? 0
    }
    
    var activeProjectCount: Int {
        projects?.filter { !$0.isArchived && $0.status == "active" }.count ?? 0
    }
    
    var completedProjectCount: Int {
        projects?.filter { $0.status == "completed" }.count ?? 0
    }
}
