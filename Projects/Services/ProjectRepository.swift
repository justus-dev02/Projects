//
//  ProjectRepository.swift
//  Projects
//
//  TaskFlow - Project Repository
//

import Foundation
import SwiftData

@MainActor
final class ProjectRepository: BaseRepository<Project> {

    // MARK: - Fetch with Relations
    func getProjectWithDetails(id: String) throws -> Project? {
        let predicate = #Predicate<Project> { $0.id == id }
        return try dataService.fetchOne(Project.self, predicate: predicate)
    }

    func getProjectsForWorkspace(workspaceId: String) throws -> [Project] {
        let predicate = #Predicate<Project> { $0.workspace?.id == workspaceId }
        let sortDescriptor = [SortDescriptor<Project>(\.createdAt, order: .reverse)]
        return try dataService.fetch(Project.self, filter: sortDescriptor, predicate: predicate)
    }

    func getActiveProjectsForWorkspace(workspaceId: String) throws -> [Project] {
        let predicate = #Predicate<Project> {
            $0.workspace?.id == workspaceId && $0.isArchived == false && $0.status == "active"
        }
        return try dataService.fetch(Project.self, filter: [], predicate: predicate)
    }

    func getProjectsByStatus(workspaceId: String, status: String) throws -> [Project] {
        let predicate = #Predicate<Project> {
            $0.workspace?.id == workspaceId && $0.status == status
        }
        return try dataService.fetch(Project.self, filter: [], predicate: predicate)
    }
    
    // MARK: - Create
    func createProject(
        name: String,
        projectDescription: String? = nil,
        color: String = "#4ECDC4",
        icon: String = "folder.fill",
        workspace: Workspace,
        status: String = "active",
        startDate: Date? = nil,
        dueDate: Date? = nil
    ) throws -> Project {
        let project = Project(
            name: name,
            projectDescription: projectDescription,
            color: color,
            icon: icon,
            status: status,
            startDate: startDate,
            dueDate: dueDate
        )
        project.workspace = workspace

        // Create default board columns
        let defaultColumns = BoardColumn.defaultColumns()
        for column in defaultColumns {
            project.boardColumns?.append(column)
        }

        dataService.insert(project)
        try dataService.save()

        return project
    }

    // MARK: - Update
    func updateProject(
        _ project: Project,
        name: String? = nil,
        projectDescription: String? = nil,
        color: String? = nil,
        icon: String? = nil,
        status: String? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil
    ) throws {
        if let name = name { project.name = name }
        if let projectDescription = projectDescription { project.projectDescription = projectDescription }
        if let color = color { project.color = color }
        if let icon = icon { project.icon = icon }
        if let status = status { project.status = status }
        if let startDate = startDate { project.startDate = startDate }
        if let dueDate = dueDate { project.dueDate = dueDate }
        project.updatedAt = Date()

        try dataService.save()
    }
    
    // MARK: - Archive
    func archiveProject(_ project: Project) throws {
        project.isArchived = true
        project.status = "archived"
        project.updatedAt = Date()
        try dataService.save()
    }
    
    func unarchiveProject(_ project: Project) throws {
        project.isArchived = false
        project.status = "active"
        project.updatedAt = Date()
        try dataService.save()
    }
    
    // MARK: - Delete
    func deleteProject(_ project: Project) throws {
        dataService.delete(project)
        try dataService.save()
    }
    
    // MARK: - Board Columns
    func getBoardColumns(for project: Project) throws -> [BoardColumn] {
        let columns = project.boardColumns ?? []
        return columns.sorted { $0.order < $1.order }
    }
    
    func addBoardColumn(to project: Project, name: String, color: String = "#E6E9ED") throws -> BoardColumn {
        let maxOrder = project.boardColumns?.max(by: { $0.order < $1.order })?.order ?? -1
        
        let column = BoardColumn(
            name: name,
            color: color,
            order: maxOrder + 1
        )
        column.project = project
        project.boardColumns?.append(column)
        
        try dataService.save()
        return column
    }
    
    func updateBoardColumn(_ column: BoardColumn, name: String? = nil, color: String? = nil, order: Int? = nil) throws {
        if let name = name { column.name = name }
        if let color = color { column.color = color }
        if let order = order { column.order = order }
        
        try dataService.save()
    }
    
    func deleteBoardColumn(_ column: BoardColumn) throws {
        dataService.delete(column)
        try dataService.save()
    }
    
    func reorderBoardColumns(_ columns: [BoardColumn]) throws {
        for (index, column) in columns.enumerated() {
            column.order = index
        }
        try dataService.save()
    }
    
    // MARK: - Members
    func addMember(to project: Project, user: User, role: String = "member") throws {
        let isMember = project.members?.contains { $0.user?.id == user.id } == true
        if isMember { return }
        
        let member = ProjectMember(role: role)
        member.user = user
        project.members?.append(member)
        
        try dataService.save()
    }
    
    func removeMember(_ member: ProjectMember, from project: Project) throws {
        dataService.delete(member)
        try dataService.save()
    }
    
    // MARK: - Statistics
    func getProjectStats(projectId: String) throws -> ProjectStats {
        guard let project = try getById(projectId) else {
            throw NSError(domain: "Project not found", code: 404)
        }
        
        let tasks = project.tasks ?? []
        let columns = project.boardColumns ?? []
        
        return ProjectStats(
            totalTasks: tasks.count,
            completedTasks: tasks.filter { $0.status == "done" }.count,
            todoTasks: tasks.filter { $0.status == "todo" }.count,
            inProgressTasks: tasks.filter { $0.status == "inProgress" }.count,
            reviewTasks: tasks.filter { $0.status == "review" }.count,
            overdueTasks: tasks.filter { $0.isOverdue }.count,
            totalColumns: columns.count,
            totalMembers: project.members?.count ?? 0
        )
    }
}

// MARK: - Project Stats
struct ProjectStats {
    let totalTasks: Int
    let completedTasks: Int
    let todoTasks: Int
    let inProgressTasks: Int
    let reviewTasks: Int
    let overdueTasks: Int
    let totalColumns: Int
    let totalMembers: Int
    
    var progressPercentage: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
}
