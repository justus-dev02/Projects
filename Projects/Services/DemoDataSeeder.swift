//
//  DemoDataSeeder.swift
//  Projects
//
//  TaskFlow - Demo Data Seeder
//

import Foundation
import SwiftData

// MARK: - Demo Data Seeder
@MainActor
final class DemoDataSeeder {
    private let dataService: DataService
    private let authService: AuthService

    init(
        dataService: DataService? = nil,
        authService: AuthService? = nil
    ) {
        self.dataService = dataService ?? DataService.shared
        self.authService = authService ?? AuthService.shared
    }

    func seedDemoData() async throws {
        // Check if demo data already exists
        let existingWorkspaces = try dataService.fetch(Workspace.self, filter: [], predicate: nil)
        if !existingWorkspaces.isEmpty {
            return // Demo data already seeded
        }

        // Get or create local user
        guard authService.currentUser != nil else {
            _ = try? authService.loginLocally()
            guard authService.currentUser != nil else {
                throw NSError(domain: "Could not create user", code: 500)
            }
            try await seedDemoData()
            return
        }

        guard let user = authService.currentUser else {
            throw NSError(domain: "Could not create user", code: 500)
        }
        
        // Create demo workspaces
        let marketingWorkspace = try createMarketingWorkspace(owner: user)
        let developmentWorkspace = try createDevelopmentWorkspace(owner: user)
        let designWorkspace = try createDesignWorkspace(owner: user)
        
        // Create demo user 2
        let demoUser2 = User(
            email: "sarah@taskflow.dev",
            displayName: "Sarah Johnson",
            avatarColor: "#FF6B6B",
            isLocalUser: false
        )
        dataService.insert(demoUser2)
        
        // Create demo user 3
        let demoUser3 = User(
            email: "mike@taskflow.dev",
            displayName: "Mike Chen",
            avatarColor: "#45B7D1",
            isLocalUser: false
        )
        dataService.insert(demoUser3)
        
        try dataService.save()
        
        // Add members to workspaces
        try addMembersToWorkspace(marketingWorkspace, members: [demoUser2, demoUser3])
        try addMembersToWorkspace(developmentWorkspace, members: [demoUser2])
        try addMembersToWorkspace(designWorkspace, members: [demoUser3])

        // Create demo notifications
        try createDemoNotifications(recipient: user, sender: demoUser2)

        try dataService.save()
    }
    
    // MARK: - Create Demo Workspaces
    private func createMarketingWorkspace(owner: User) throws -> Workspace {
        let workspace = Workspace(
            name: "Marketing",
            workspaceDescription: "Marketing campaigns and content creation",
            color: "#2D5BFF",
            icon: "megaphone.fill"
        )
        workspace.owner = owner
        dataService.insert(workspace)
        
        // Create projects
        let websiteProject = try createWebsiteProject(workspace: workspace, owner: owner)
        let socialMediaProject = try createSocialMediaProject(workspace: workspace, owner: owner)
        let contentProject = try createContentProject(workspace: workspace, owner: owner)
        
        workspace.projects = [websiteProject, socialMediaProject, contentProject]
        
        // Add default labels
        let defaultLabels = Label.defaultLabels()
        workspace.labels = defaultLabels
        
        return workspace
    }
    
    private func createDevelopmentWorkspace(owner: User) throws -> Workspace {
        let workspace = Workspace(
            name: "Development",
            workspaceDescription: "Software development and engineering",
            color: "#00BA88",
            icon: "chevron.left.slash.chevron.right"
        )
        workspace.owner = owner
        dataService.insert(workspace)
        
        // Create projects
        let backendProject = try createBackendProject(workspace: workspace, owner: owner)
        let frontendProject = try createFrontendProject(workspace: workspace, owner: owner)
        let mobileProject = try createMobileProject(workspace: workspace, owner: owner)
        
        workspace.projects = [backendProject, frontendProject, mobileProject]
        
        // Add default labels
        let defaultLabels = Label.defaultLabels()
        workspace.labels = defaultLabels
        
        return workspace
    }
    
    private func createDesignWorkspace(owner: User) throws -> Workspace {
        let workspace = Workspace(
            name: "Design",
            workspaceDescription: "UI/UX design and creative work",
            color: "#A855F7",
            icon: "paintbrush.fill"
        )
        workspace.owner = owner
        dataService.insert(workspace)
        
        // Create projects
        let uiProject = try createUIProject(workspace: workspace, owner: owner)
        let brandingProject = try createBrandingProject(workspace: workspace, owner: owner)
        
        workspace.projects = [uiProject, brandingProject]
        
        // Add default labels
        let defaultLabels = Label.defaultLabels()
        workspace.labels = defaultLabels
        
        return workspace
    }
    
    // MARK: - Create Demo Projects
    private func createWebsiteProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Website Redesign",
            projectDescription: "Complete redesign of the company website",
            color: "#4ECDC4",
            icon: "globe",
            status: "active",
            startDate: Date(),
            dueDate: Calendar.current.date(byAdding: .month, value: 2, to: Date())!
        )
        project.workspace = workspace
        dataService.insert(project)
        
        // Create board columns
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        // Create demo tasks
        let tasks = try createWebsiteTasks(columns: columns, owner: owner)
        project.tasks = tasks
        
        return project
    }
    
    private func createSocialMediaProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Social Media Campaign",
            projectDescription: "Q1 social media marketing campaign",
            color: "#FF6B6B",
            icon: "heart.fill",
            status: "active"
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    private func createContentProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Content Creation",
            projectDescription: "Blog posts, videos, and marketing materials",
            color: "#FFB020",
            icon: "doc.text.fill",
            status: "active"
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    private func createBackendProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Backend API",
            projectDescription: "RESTful API development",
            color: "#45B7D1",
            icon: "cpu.fill",
            status: "active"
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    private func createFrontendProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Frontend App",
            projectDescription: "React/TypeScript application",
            color: "#96CEB4",
            icon: "display.fill",
            status: "active"
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    private func createMobileProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Mobile App",
            projectDescription: "iOS/Android mobile application",
            color: "#FFEAA7",
            icon: "iphone",
            status: "paused",
            dueDate: Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    private func createUIProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "UI Component Library",
            projectDescription: "Design system and component library",
            color: "#DDA0DD",
            icon: "square.grid.2x2.fill",
            status: "active"
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    private func createBrandingProject(workspace: Workspace, owner: User) throws -> Project {
        let project = Project(
            name: "Brand Guidelines",
            projectDescription: "Company branding and style guide",
            color: "#F7DC6F",
            icon: "star.fill",
            status: "completed"
        )
        project.workspace = workspace
        dataService.insert(project)
        
        let columns = BoardColumn.defaultColumns()
        for column in columns {
            column.project = project
            dataService.insert(column)
        }
        project.boardColumns = columns
        
        return project
    }
    
    // MARK: - Create Demo Tasks
    private func createWebsiteTasks(columns: [BoardColumn], owner: User) throws -> [Task] {
        var tasks: [Task] = []
        
        guard columns.count >= 4 else { return tasks }
        
        // To Do tasks
        let todoColumn = columns[0]
        let task1 = Task(
            title: "Design homepage mockup",
            taskDescription: "Create wireframes and high-fidelity mockups for the new homepage",
            priority: "high",
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        )
        task1.column = todoColumn
        task1.project = todoColumn.project
        task1.assignee = owner
        dataService.insert(task1)
        tasks.append(task1)

        let task2 = Task(
            title: "Set up analytics tracking",
            taskDescription: "Implement Google Analytics 4 and custom event tracking",
            priority: "medium",
            dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        )
        task2.column = todoColumn
        task2.project = todoColumn.project
        dataService.insert(task2)
        tasks.append(task2)

        // In Progress tasks
        let inProgressColumn = columns[1]
        let task3 = Task(
            title: "Implement responsive navigation",
            taskDescription: "Create mobile-first responsive navigation menu",
            priority: "high",
            dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        task3.column = inProgressColumn
        task3.project = inProgressColumn.project
        task3.assignee = owner
        dataService.insert(task3)
        tasks.append(task3)
        
        // Add subtasks
        let subtask1 = Subtask(title: "Create mobile menu component", order: 0)
        subtask1.task = task3
        dataService.insert(subtask1)
        
        let subtask2 = Subtask(title: "Add hamburger icon animation", order: 1)
        subtask2.task = task3
        dataService.insert(subtask2)
        
        let subtask3 = Subtask(title: "Test on multiple devices", order: 2)
        subtask3.task = task3
        subtask3.isCompleted = true
        subtask3.completedAt = Date()
        dataService.insert(subtask3)
        
        let task4 = Task(
            title: "Optimize images for web",
            taskDescription: "Compress and convert all images to WebP format",
            priority: "low",
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        )
        task4.column = inProgressColumn
        task4.project = inProgressColumn.project
        dataService.insert(task4)
        tasks.append(task4)

        // Review tasks
        let reviewColumn = columns[2]
        let task5 = Task(
            title: "SEO audit and optimization",
            taskDescription: "Review and optimize meta tags, headings, and content structure",
            priority: "urgent",
            dueDate: Date()
        )
        task5.column = reviewColumn
        task5.project = reviewColumn.project
        task5.assignee = owner
        dataService.insert(task5)
        tasks.append(task5)

        // Done tasks
        let doneColumn = columns[3]
        let task6 = Task(
            title: "Set up project repository",
            taskDescription: "Initialize Git repo and configure CI/CD pipeline",
            priority: "high",
            dueDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        )
        task6.column = doneColumn
        task6.project = doneColumn.project
        task6.assignee = owner
        task6.status = "done"
        task6.completedAt = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        dataService.insert(task6)
        tasks.append(task6)

        let task7 = Task(
            title: "Define design system",
            taskDescription: "Create color palette, typography, and component specifications",
            priority: "high",
            dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        )
        task7.column = doneColumn
        task7.project = doneColumn.project
        task7.status = "done"
        task7.completedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        dataService.insert(task7)
        tasks.append(task7)
        
        return tasks
    }
    
    // MARK: - Helper Functions
    private func addMembersToWorkspace(_ workspace: Workspace, members: [User]) throws {
        for member in members {
            let workspaceMember = WorkspaceMember(role: "member")
            workspaceMember.user = member
            workspace.members?.append(workspaceMember)
        }
    }
    
    private func createDemoNotifications(recipient: User, sender: User) throws {
        let notifications = [
            NotificationModel(
                title: "Welcome to TaskFlow!",
                message: "Get started by creating your first workspace.",
                type: "info"
            ),
            NotificationModel(
                title: "Task Assigned",
                message: "\(sender.displayName) assigned you to \"Design homepage mockup\"",
                type: "assignment"
            ),
            NotificationModel(
                title: "Comment on your task",
                message: "\(sender.displayName) commented on \"Implement responsive navigation\"",
                type: "comment"
            ),
            NotificationModel(
                title: "Task Due Soon",
                message: "\"SEO audit and optimization\" is due today",
                type: "dueDate"
            )
        ]

        for notification in notifications {
            notification.recipient = recipient
            notification.sender = sender
            dataService.insert(notification)
        }
    }
}
