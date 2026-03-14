//
//  WorkspaceRepository.swift
//  Projects
//
//  TaskFlow - Workspace Repository
//

import Foundation
import SwiftData

@MainActor
final class WorkspaceRepository: BaseRepository<Workspace> {

    // MARK: - Fetch with Relations
    func getWorkspaceWithDetails(id: String) throws -> Workspace? {
        let predicate = #Predicate<Workspace> { $0.id == id }
        return try dataService.fetchOne(Workspace.self, predicate: predicate)
    }

    func getWorkspacesForUser(userId: String) throws -> [Workspace] {
        // Get workspaces where user is owner or member
        let allWorkspaces = try getAll()

        return allWorkspaces.filter { workspace in
            workspace.owner?.id == userId ||
            workspace.members?.contains { $0.user?.id == userId } == true
        }
    }

    func getActiveWorkspaces() throws -> [Workspace] {
        let predicate = #Predicate<Workspace> { $0.isArchived == false }
        return try dataService.fetch(Workspace.self, filter: [], predicate: predicate)
    }

    // MARK: - Create
    func createWorkspace(
        name: String,
        workspaceDescription: String? = nil,
        color: String = "#2D5BFF",
        icon: String = "briefcase.fill",
        owner: User
    ) throws -> Workspace {
        let workspace = Workspace(
            name: name,
            workspaceDescription: workspaceDescription,
            color: color,
            icon: icon
        )
        workspace.owner = owner

        // Create default labels
        let defaultLabels = Label.defaultLabels()
        for label in defaultLabels {
            workspace.labels?.append(label)
        }

        // Create workspace member for owner
        let member = WorkspaceMember(role: "owner")
        member.user = owner
        workspace.members?.append(member)

        dataService.insert(workspace)
        try dataService.save()

        return workspace
    }

    // MARK: - Update
    func updateWorkspace(_ workspace: Workspace, name: String? = nil, workspaceDescription: String? = nil, color: String? = nil, icon: String? = nil) throws {
        if let name = name { workspace.name = name }
        if let workspaceDescription = workspaceDescription { workspace.workspaceDescription = workspaceDescription }
        if let color = color { workspace.color = color }
        if let icon = icon { workspace.icon = icon }
        workspace.updatedAt = Date()

        try dataService.save()
    }
    
    // MARK: - Archive
    func archiveWorkspace(_ workspace: Workspace) throws {
        workspace.isArchived = true
        workspace.updatedAt = Date()
        try dataService.save()
    }
    
    func unarchiveWorkspace(_ workspace: Workspace) throws {
        workspace.isArchived = false
        workspace.updatedAt = Date()
        try dataService.save()
    }
    
    // MARK: - Delete
    func deleteWorkspace(_ workspace: Workspace) throws {
        dataService.delete(workspace)
        try dataService.save()
    }
    
    // MARK: - Members
    func addMember(to workspace: Workspace, user: User, role: String = "member") throws {
        // Check if already member
        let isMember = workspace.members?.contains { $0.user?.id == user.id } == true
        if isMember { return }
        
        let member = WorkspaceMember(role: role)
        member.user = user
        workspace.members?.append(member)
        
        try dataService.save()
    }
    
    func removeMember(_ member: WorkspaceMember, from workspace: Workspace) throws {
        dataService.delete(member)
        try dataService.save()
    }
    
    func updateMemberRole(_ member: WorkspaceMember, role: String) throws {
        member.role = role
        try dataService.save()
    }
    
    // MARK: - Statistics
    func getWorkspaceStats(workspaceId: String) throws -> WorkspaceStats {
        guard let workspace = try getById(workspaceId) else {
            throw NSError(domain: "Workspace not found", code: 404)
        }
        
        let projects = workspace.projects ?? []
        let tasks = projects.flatMap { $0.tasks ?? [] }
        
        return WorkspaceStats(
            totalProjects: projects.count,
            activeProjects: projects.filter { $0.status == "active" }.count,
            completedProjects: projects.filter { $0.status == "completed" }.count,
            totalTasks: tasks.count,
            completedTasks: tasks.filter { $0.status == "done" }.count,
            overdueTasks: tasks.filter { $0.isOverdue }.count,
            totalMembers: workspace.members?.count ?? 0
        )
    }
}

// MARK: - Workspace Stats
struct WorkspaceStats {
    let totalProjects: Int
    let activeProjects: Int
    let completedProjects: Int
    let totalTasks: Int
    let completedTasks: Int
    let overdueTasks: Int
    let totalMembers: Int
    
    var taskCompletionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
}
