//
//  DashboardService.swift
//  Projects
//
//  TaskFlow - Dashboard Service
//

import Foundation
import SwiftData

// MARK: - Dashboard Stats
struct DashboardStats {
    // Overall Stats
    let totalTasks: Int
    let completedTasks: Int
    let inProgressTasks: Int
    let overdueTasks: Int
    
    // Task Lists
    let dueToday: [Task]
    let dueTomorrow: [Task]
    let highPriority: [Task]
    let recentTasks: [Task]
    
    // Workspace Overview
    let workspaceStats: [WorkspaceOverview]
    
    // Computed
    var taskCompletionRate: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
    
    var overduePercentage: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(overdueTasks) / Double(totalTasks) * 100
    }
}

struct WorkspaceOverview {
    let workspaceId: String
    let workspaceName: String
    let workspaceColor: String
    let totalProjects: Int
    let totalTasks: Int
    let completedTasks: Int
    let progressPercentage: Double
}

// MARK: - Dashboard Service
@MainActor
final class DashboardService {
    private let dataService: DataService
    private let taskRepo: TaskRepository
    private let workspaceRepo: WorkspaceRepository
    private let projectRepo: ProjectRepository

    init(
        dataService: DataService? = nil,
        taskRepo: TaskRepository? = nil,
        workspaceRepo: WorkspaceRepository? = nil,
        projectRepo: ProjectRepository? = nil
    ) {
        self.dataService = dataService ?? DataService.shared
        self.taskRepo = taskRepo ?? TaskRepository(dataService: self.dataService)
        self.workspaceRepo = workspaceRepo ?? WorkspaceRepository(dataService: self.dataService)
        self.projectRepo = projectRepo ?? ProjectRepository(dataService: self.dataService)
    }
    
    // MARK: - Get Dashboard Stats
    func getDashboardStats(for userId: String? = nil) throws -> DashboardStats {
        // Fetch all tasks
        var allTasks: [Task] = []
        
        if let userId = userId {
            // Get tasks assigned to user
            allTasks = try taskRepo.getTasksForUser(userId: userId)
        } else {
            // Get all tasks from all projects
            let workspaces = try workspaceRepo.getAll()
            for workspace in workspaces {
                let projects = workspace.projects ?? []
                for project in projects {
                    let tasks = project.tasks ?? []
                    allTasks.append(contentsOf: tasks)
                }
            }
        }
        
        // Calculate stats
        let totalTasks = allTasks.count
        let completedTasks = allTasks.filter { $0.status == "done" }.count
        let inProgressTasks = allTasks.filter { $0.status == "inProgress" }.count
        let overdueTasks = allTasks.filter { $0.isOverdue }.count
        
        // Task lists
        let dueToday = allTasks.filter { $0.isDueToday }.sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
        
        let dueTomorrow = allTasks.filter { $0.isDueTomorrow }.sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
        
        let highPriority = allTasks.filter {
            $0.priority == "high" || $0.priority == "urgent"
        }.sorted {
            Task.Priority(rawValue: $0.priority)?.weight ?? 0 >
            Task.Priority(rawValue: $1.priority)?.weight ?? 0
        }
        
        let recentTasks = allTasks.sorted {
            $0.updatedAt > $1.updatedAt
        }.prefix(5).map { $0 }
        
        // Workspace overview
        let workspaceStats = try getWorkspaceOverview()
        
        return DashboardStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            inProgressTasks: inProgressTasks,
            overdueTasks: overdueTasks,
            dueToday: dueToday,
            dueTomorrow: dueTomorrow,
            highPriority: highPriority,
            recentTasks: recentTasks,
            workspaceStats: workspaceStats
        )
    }
    
    // MARK: - Workspace Overview
    private func getWorkspaceOverview() throws -> [WorkspaceOverview] {
        let workspaces = try workspaceRepo.getActiveWorkspaces()
        
        return workspaces.map { workspace in
            let projects = workspace.projects ?? []
            let activeProjects = projects.filter { $0.status == "active" && !$0.isArchived }
            
            var totalTasks = 0
            var completedTasks = 0
            
            for project in activeProjects {
                let tasks = project.tasks ?? []
                totalTasks += tasks.count
                completedTasks += tasks.filter { $0.status == "done" }.count
            }
            
            let progress = totalTasks > 0
                ? Double(completedTasks) / Double(totalTasks) * 100
                : 0
            
            return WorkspaceOverview(
                workspaceId: workspace.id,
                workspaceName: workspace.name,
                workspaceColor: workspace.color,
                totalProjects: activeProjects.count,
                totalTasks: totalTasks,
                completedTasks: completedTasks,
                progressPercentage: progress
            )
        }
    }
    
    // MARK: - Get Stats for Specific Workspace
    func getWorkspaceDashboardStats(workspaceId: String) throws -> DashboardStats {
        guard let workspace = try workspaceRepo.getById(workspaceId) else {
            throw NSError(domain: "Workspace not found", code: 404)
        }
        
        let projects = workspace.projects ?? []
        var allTasks: [Task] = []
        
        for project in projects {
            let tasks = project.tasks ?? []
            allTasks.append(contentsOf: tasks)
        }
        
        let totalTasks = allTasks.count
        let completedTasks = allTasks.filter { $0.status == "done" }.count
        let inProgressTasks = allTasks.filter { $0.status == "inProgress" }.count
        let overdueTasks = allTasks.filter { $0.isOverdue }.count
        
        let dueToday = allTasks.filter { $0.isDueToday }
        let dueTomorrow = allTasks.filter { $0.isDueTomorrow }
        let highPriority = allTasks.filter {
            $0.priority == "high" || $0.priority == "urgent"
        }
        let recentTasks = allTasks.sorted {
            $0.updatedAt > $1.updatedAt
        }.prefix(5).map { $0 }
        
        let workspaceStats = [
            WorkspaceOverview(
                workspaceId: workspace.id,
                workspaceName: workspace.name,
                workspaceColor: workspace.color,
                totalProjects: projects.filter { $0.status == "active" }.count,
                totalTasks: totalTasks,
                completedTasks: completedTasks,
                progressPercentage: totalTasks > 0
                    ? Double(completedTasks) / Double(totalTasks) * 100
                    : 0
            )
        ]
        
        return DashboardStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            inProgressTasks: inProgressTasks,
            overdueTasks: overdueTasks,
            dueToday: dueToday,
            dueTomorrow: dueTomorrow,
            highPriority: highPriority,
            recentTasks: recentTasks,
            workspaceStats: workspaceStats
        )
    }
    
    // MARK: - Get Stats for Specific Project
    func getProjectDashboardStats(projectId: String) throws -> ProjectStats {
        try projectRepo.getProjectStats(projectId: projectId)
    }
}
