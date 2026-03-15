//
//  ProjectWorkspaceRepositoryTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for ProjectRepository and WorkspaceRepository
//

import XCTest
@testable import Projects
import SwiftData

@MainActor
final class ProjectWorkspaceRepositoryTests: XCTestCase {
    
    var projectRepository: ProjectRepository!
    var workspaceRepository: WorkspaceRepository!
    var dataService: DataService!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            User.self,
            Workspace.self,
            WorkspaceMember.self,
            Project.self,
            ProjectMember.self,
            BoardColumn.self,
            Task.self,
            Label.self,
            Invitation.self,
            TaskTemplate.self,
            CustomFieldDefinition.self,
            SavedView.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = container.mainContext
        dataService = DataService(modelContext: modelContext)
        projectRepository = ProjectRepository(dataService: dataService)
        workspaceRepository = WorkspaceRepository(dataService: dataService)
    }
    
    override func tearDown() async throws {
        projectRepository = nil
        workspaceRepository = nil
        dataService = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - ProjectRepository Create Tests
    
    func testCreateProject_Success() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        dataService.insert(workspace)
        dataService.insert(owner)
        try dataService.save()
        
        // When
        let project = try projectRepository.createProject(
            name: "New Project",
            projectDescription: "Project description",
            color: "#FF6B6B",
            icon: "star.fill",
            workspace: workspace,
            status: "active"
        )
        
        // Then
        XCTAssertEqual(project.name, "New Project")
        XCTAssertEqual(project.projectDescription, "Project description")
        XCTAssertEqual(project.color, "#FF6B6B")
        XCTAssertEqual(project.icon, "star.fill")
        XCTAssertEqual(project.workspace, workspace)
        XCTAssertEqual(project.status, "active")
        XCTAssertFalse(project.isArchived)
    }
    
    func testCreateProject_CreatesDefaultColumns() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        dataService.insert(workspace)
        dataService.insert(owner)
        try dataService.save()
        
        // When
        let project = try projectRepository.createProject(
            name: "New Project",
            workspace: workspace
        )
        
        // Then
        XCTAssertEqual(project.boardColumns?.count, 4)
        XCTAssertEqual(project.boardColumns?[0].name, "To Do")
        XCTAssertEqual(project.boardColumns?[1].name, "In Progress")
        XCTAssertEqual(project.boardColumns?[2].name, "Review")
        XCTAssertEqual(project.boardColumns?[3].name, "Done")
    }
    
    func testCreateProject_WithDates() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        dataService.insert(workspace)
        dataService.insert(owner)
        try dataService.save()
        
        let startDate = Date()
        let dueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        // When
        let project = try projectRepository.createProject(
            name: "New Project",
            workspace: workspace,
            startDate: startDate,
            dueDate: dueDate
        )
        
        // Then
        XCTAssertEqual(project.startDate, startDate)
        XCTAssertEqual(project.dueDate, dueDate)
    }
    
    // MARK: - ProjectRepository Fetch Tests
    
    func testGetProjectWithDetails() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        let fetched = try projectRepository.getProjectWithDetails(id: project.id)
        
        // Then
        XCTAssertEqual(fetched?.id, project.id)
        XCTAssertEqual(fetched?.name, "Test Project")
    }
    
    func testGetProjectWithDetails_NotFound() throws {
        // When
        let fetched = try projectRepository.getProjectWithDetails(id: "nonexistent-id")
        
        // Then
        XCTAssertNil(fetched)
    }
    
    func testGetProjectsForWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        dataService.insert(workspace)
        dataService.insert(owner)
        
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        let project3 = Project(name: "Project 3")
        project1.workspace = workspace
        project2.workspace = workspace
        project3.workspace = workspace
        dataService.insert(project1)
        dataService.insert(project2)
        dataService.insert(project3)
        try dataService.save()
        
        // When
        let projects = try projectRepository.getProjectsForWorkspace(workspaceId: workspace.id)
        
        // Then
        XCTAssertEqual(projects.count, 3)
    }
    
    func testGetActiveProjectsForWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        dataService.insert(workspace)
        dataService.insert(owner)
        
        let project1 = Project(name: "Project 1", status: "active")
        let project2 = Project(name: "Project 2", status: "active")
        let project3 = Project(name: "Project 3", status: "completed")
        let project4 = Project(name: "Project 4")
        project4.isArchived = true
        project1.workspace = workspace
        project2.workspace = workspace
        project3.workspace = workspace
        project4.workspace = workspace
        dataService.insert(project1)
        dataService.insert(project2)
        dataService.insert(project3)
        dataService.insert(project4)
        try dataService.save()
        
        // When
        let projects = try projectRepository.getActiveProjectsForWorkspace(workspaceId: workspace.id)
        
        // Then
        XCTAssertEqual(projects.count, 2)
    }
    
    func testGetProjectsByStatus() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        dataService.insert(workspace)
        dataService.insert(owner)
        
        let project1 = Project(name: "Project 1", status: "active")
        let project2 = Project(name: "Project 2", status: "paused")
        let project3 = Project(name: "Project 3", status: "completed")
        project1.workspace = workspace
        project2.workspace = workspace
        project3.workspace = workspace
        dataService.insert(project1)
        dataService.insert(project2)
        dataService.insert(project3)
        try dataService.save()
        
        // When
        let projects = try projectRepository.getProjectsByStatus(workspaceId: workspace.id, status: "active")
        
        // Then
        XCTAssertEqual(projects.count, 1)
    }
    
    // MARK: - ProjectRepository Update Tests
    
    func testUpdateProject_Name() throws {
        // Given
        let project = Project(name: "Original Name")
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.updateProject(project, name: "Updated Name")
        
        // Then
        XCTAssertEqual(project.name, "Updated Name")
    }
    
    func testUpdateProject_Description() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.updateProject(project, projectDescription: "New Description")
        
        // Then
        XCTAssertEqual(project.projectDescription, "New Description")
    }
    
    func testUpdateProject_ColorAndIcon() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.updateProject(project, color: "#45B7D1", icon: "folder.fill")
        
        // Then
        XCTAssertEqual(project.color, "#45B7D1")
        XCTAssertEqual(project.icon, "folder.fill")
    }
    
    func testUpdateProject_Status() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.updateProject(project, status: "completed")
        
        // Then
        XCTAssertEqual(project.status, "completed")
    }
    
    func testUpdateProject_Dates() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        let startDate = Date()
        let dueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        // When
        try projectRepository.updateProject(project, startDate: startDate, dueDate: dueDate)
        
        // Then
        XCTAssertEqual(project.startDate, startDate)
        XCTAssertEqual(project.dueDate, dueDate)
    }
    
    func testUpdateProject_UpdatesTimestamp() throws {
        // Given
        let project = Project(name: "Test Project")
        let originalUpdatedAt = project.updatedAt
        dataService.insert(project)
        try dataService.save()
        
        // When
        Thread.sleep(forTimeInterval: 0.1)
        try projectRepository.updateProject(project, name: "Updated")
        
        // Then
        XCTAssertGreaterThan(project.updatedAt, originalUpdatedAt)
    }
    
    // MARK: - ProjectRepository Archive Tests
    
    func testArchiveProject() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.archiveProject(project)
        
        // Then
        XCTAssertTrue(project.isArchived)
        XCTAssertEqual(project.status, "archived")
    }
    
    func testUnarchiveProject() throws {
        // Given
        let project = Project(name: "Test Project")
        project.isArchived = true
        project.status = "archived"
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.unarchiveProject(project)
        
        // Then
        XCTAssertFalse(project.isArchived)
        XCTAssertEqual(project.status, "active")
    }
    
    // MARK: - ProjectRepository Delete Tests
    
    func testDeleteProject() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        try projectRepository.deleteProject(project)
        
        // Then
        let fetched = try projectRepository.getProjectWithDetails(id: project.id)
        XCTAssertNil(fetched)
    }
    
    // MARK: - ProjectRepository Board Column Tests
    
    func testGetBoardColumns() throws {
        // Given
        let project = Project(name: "Test Project")
        let column1 = BoardColumn(name: "To Do", order: 0)
        let column2 = BoardColumn(name: "Done", order: 1)
        column1.project = project
        column2.project = project
        project.boardColumns = [column1, column2]
        dataService.insert(project)
        try dataService.save()
        
        // When
        let columns = try projectRepository.getBoardColumns(for: project)
        
        // Then
        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0].name, "To Do")
        XCTAssertEqual(columns[1].name, "Done")
    }
    
    func testAddBoardColumn() throws {
        // Given
        let project = Project(name: "Test Project")
        dataService.insert(project)
        try dataService.save()
        
        // When
        let column = try projectRepository.addBoardColumn(
            to: project,
            name: "New Column",
            color: "#FF6B6B"
        )
        
        // Then
        XCTAssertEqual(column.name, "New Column")
        XCTAssertEqual(column.color, "#FF6B6B")
        XCTAssertEqual(column.project, project)
        XCTAssertEqual(project.boardColumns?.count, 1)
    }
    
    func testAddBoardColumn_SetsOrder() throws {
        // Given
        let project = Project(name: "Test Project")
        let column1 = BoardColumn(name: "Column 1")
        column1.project = project
        column1.order = 0
        project.boardColumns = [column1]
        dataService.insert(project)
        try dataService.save()
        
        // When
        let column2 = try projectRepository.addBoardColumn(to: project, name: "Column 2")
        
        // Then
        XCTAssertEqual(column2.order, 1)
    }
    
    func testUpdateBoardColumn() throws {
        // Given
        let column = BoardColumn(name: "Original")
        dataService.insert(column)
        try dataService.save()
        
        // When
        try projectRepository.updateBoardColumn(column, name: "Updated", color: "#45B7D1")
        
        // Then
        XCTAssertEqual(column.name, "Updated")
        XCTAssertEqual(column.color, "#45B7D1")
    }
    
    func testDeleteBoardColumn() throws {
        // Given
        let column = BoardColumn(name: "Test Column")
        dataService.insert(column)
        try dataService.save()
        
        // When
        try projectRepository.deleteBoardColumn(column)
        
        // Then
        let predicate = #Predicate<BoardColumn> { $0.id == column.id }
        let fetched = try dataService.fetchOne(BoardColumn.self, predicate: predicate)
        XCTAssertNil(fetched)
    }
    
    func testReorderBoardColumns() throws {
        // Given
        let column1 = BoardColumn(name: "Column 1", order: 0)
        let column2 = BoardColumn(name: "Column 2", order: 1)
        let column3 = BoardColumn(name: "Column 3", order: 2)
        dataService.insert(column1)
        dataService.insert(column2)
        dataService.insert(column3)
        try dataService.save()
        
        // When - Reverse order
        try projectRepository.reorderBoardColumns([column3, column2, column1])
        
        // Then
        XCTAssertEqual(column1.order, 2)
        XCTAssertEqual(column2.order, 1)
        XCTAssertEqual(column3.order, 0)
    }
    
    // MARK: - ProjectRepository Member Tests
    
    func testAddMember() throws {
        // Given
        let project = Project(name: "Test Project")
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(project)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try projectRepository.addMember(to: project, user: user, role: "admin")
        
        // Then
        XCTAssertEqual(project.members?.count, 1)
        XCTAssertEqual(project.members?.first?.user, user)
        XCTAssertEqual(project.members?.first?.role, "admin")
    }
    
    func testAddMember_DoesNotAddDuplicate() throws {
        // Given
        let project = Project(name: "Test Project")
        let user = User(email: "user@example.com", displayName: "User")
        let member = ProjectMember()
        member.user = user
        project.members = [member]
        dataService.insert(project)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try projectRepository.addMember(to: project, user: user)
        
        // Then
        XCTAssertEqual(project.members?.count, 1)
    }
    
    func testRemoveMember() throws {
        // Given
        let project = Project(name: "Test Project")
        let user = User(email: "user@example.com", displayName: "User")
        let member = ProjectMember()
        member.user = user
        project.members = [member]
        dataService.insert(project)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try projectRepository.removeMember(member, from: project)
        
        // Then
        XCTAssertEqual(project.members?.count, 0)
    }
    
    // MARK: - ProjectRepository Statistics Tests
    
    func testGetProjectStats() throws {
        // Given
        let project = Project(name: "Test Project")
        let column = BoardColumn(name: "To Do")
        column.project = project
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        let task4 = Task(title: "Task 4")
        let task5 = Task(title: "Task 5")
        
        task1.status = "todo"
        task2.status = "inProgress"
        task3.status = "review"
        task4.status = "done"
        task5.status = "done"
        task5.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Overdue
        
        task1.column = column
        task2.column = column
        task3.column = column
        task4.column = column
        task5.column = column
        
        project.boardColumns = [column]
        project.tasks = [task1, task2, task3, task4, task5]
        
        let member = ProjectMember()
        project.members = [member]
        
        dataService.insert(project)
        try dataService.save()
        
        // When
        let stats = try projectRepository.getProjectStats(projectId: project.id)
        
        // Then
        XCTAssertEqual(stats.totalTasks, 5)
        XCTAssertEqual(stats.completedTasks, 2)
        XCTAssertEqual(stats.todoTasks, 1)
        XCTAssertEqual(stats.inProgressTasks, 1)
        XCTAssertEqual(stats.reviewTasks, 1)
        XCTAssertEqual(stats.totalColumns, 1)
        XCTAssertEqual(stats.totalMembers, 1)
        XCTAssertEqual(stats.progressPercentage, 40.0)
    }
    
    // MARK: - WorkspaceRepository Create Tests
    
    func testCreateWorkspace_Success() throws {
        // Given
        let owner = User(email: "owner@example.com", displayName: "Owner")
        dataService.insert(owner)
        try dataService.save()
        
        // When
        let workspace = try workspaceRepository.createWorkspace(
            name: "New Workspace",
            workspaceDescription: "Workspace description",
            color: "#FF6B6B",
            icon: "star.fill",
            owner: owner
        )
        
        // Then
        XCTAssertEqual(workspace.name, "New Workspace")
        XCTAssertEqual(workspace.workspaceDescription, "Workspace description")
        XCTAssertEqual(workspace.color, "#FF6B6B")
        XCTAssertEqual(workspace.icon, "star.fill")
        XCTAssertEqual(workspace.owner, owner)
        XCTAssertFalse(workspace.isArchived)
    }
    
    func testCreateWorkspace_CreatesDefaultLabels() throws {
        // Given
        let owner = User(email: "owner@example.com", displayName: "Owner")
        dataService.insert(owner)
        try dataService.save()
        
        // When
        let workspace = try workspaceRepository.createWorkspace(
            name: "New Workspace",
            owner: owner
        )
        
        // Then
        XCTAssertEqual(workspace.labels?.count, 8)
    }
    
    func testCreateWorkspace_CreatesOwnerMember() throws {
        // Given
        let owner = User(email: "owner@example.com", displayName: "Owner")
        dataService.insert(owner)
        try dataService.save()
        
        // When
        let workspace = try workspaceRepository.createWorkspace(
            name: "New Workspace",
            owner: owner
        )
        
        // Then
        XCTAssertEqual(workspace.members?.count, 1)
        XCTAssertEqual(workspace.members?.first?.user, owner)
        XCTAssertEqual(workspace.members?.first?.role, "owner")
    }
    
    // MARK: - WorkspaceRepository Fetch Tests
    
    func testGetWorkspaceWithDetails() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        let fetched = try workspaceRepository.getWorkspaceWithDetails(id: workspace.id)
        
        // Then
        XCTAssertEqual(fetched?.id, workspace.id)
        XCTAssertEqual(fetched?.name, "Test Workspace")
    }
    
    func testGetWorkspaceWithDetails_NotFound() throws {
        // When
        let fetched = try workspaceRepository.getWorkspaceWithDetails(id: "nonexistent-id")
        
        // Then
        XCTAssertNil(fetched)
    }
    
    func testGetWorkspacesForUser_AsOwner() throws {
        // Given
        let owner = User(email: "owner@example.com", displayName: "Owner")
        dataService.insert(owner)
        
        let workspace1 = Workspace(name: "Workspace 1")
        let workspace2 = Workspace(name: "Workspace 2")
        workspace1.owner = owner
        workspace2.owner = owner
        dataService.insert(workspace1)
        dataService.insert(workspace2)
        try dataService.save()
        
        // When
        let workspaces = try workspaceRepository.getWorkspacesForUser(userId: owner.id)
        
        // Then
        XCTAssertEqual(workspaces.count, 2)
    }
    
    func testGetWorkspacesForUser_AsMember() throws {
        // Given
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(user)
        
        let workspace = Workspace(name: "Test Workspace")
        let member = WorkspaceMember()
        member.user = user
        workspace.members = [member]
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        let workspaces = try workspaceRepository.getWorkspacesForUser(userId: user.id)
        
        // Then
        XCTAssertEqual(workspaces.count, 1)
    }
    
    func testGetActiveWorkspaces() throws {
        // Given
        let workspace1 = Workspace(name: "Workspace 1")
        let workspace2 = Workspace(name: "Workspace 2")
        let workspace3 = Workspace(name: "Workspace 3")
        workspace3.isArchived = true
        dataService.insert(workspace1)
        dataService.insert(workspace2)
        dataService.insert(workspace3)
        try dataService.save()
        
        // When
        let workspaces = try workspaceRepository.getActiveWorkspaces()
        
        // Then
        XCTAssertEqual(workspaces.count, 2)
    }
    
    // MARK: - WorkspaceRepository Update Tests
    
    func testUpdateWorkspace_Name() throws {
        // Given
        let workspace = Workspace(name: "Original Name")
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        try workspaceRepository.updateWorkspace(workspace, name: "Updated Name")
        
        // Then
        XCTAssertEqual(workspace.name, "Updated Name")
    }
    
    func testUpdateWorkspace_Description() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        try workspaceRepository.updateWorkspace(workspace, workspaceDescription: "New Description")
        
        // Then
        XCTAssertEqual(workspace.workspaceDescription, "New Description")
    }
    
    func testUpdateWorkspace_ColorAndIcon() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        try workspaceRepository.updateWorkspace(workspace, color: "#45B7D1", icon: "briefcase.fill")
        
        // Then
        XCTAssertEqual(workspace.color, "#45B7D1")
        XCTAssertEqual(workspace.icon, "briefcase.fill")
    }
    
    // MARK: - WorkspaceRepository Archive Tests
    
    func testArchiveWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        try workspaceRepository.archiveWorkspace(workspace)
        
        // Then
        XCTAssertTrue(workspace.isArchived)
    }
    
    func testUnarchiveWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        workspace.isArchived = true
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        try workspaceRepository.unarchiveWorkspace(workspace)
        
        // Then
        XCTAssertFalse(workspace.isArchived)
    }
    
    // MARK: - WorkspaceRepository Delete Tests
    
    func testDeleteWorkspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        try workspaceRepository.deleteWorkspace(workspace)
        
        // Then
        let fetched = try workspaceRepository.getWorkspaceWithDetails(id: workspace.id)
        XCTAssertNil(fetched)
    }
    
    // MARK: - WorkspaceRepository Member Tests
    
    func testAddMember() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(workspace)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try workspaceRepository.addMember(to: workspace, user: user, role: "admin")
        
        // Then
        XCTAssertEqual(workspace.members?.count, 1)
        XCTAssertEqual(workspace.members?.first?.user, user)
        XCTAssertEqual(workspace.members?.first?.role, "admin")
    }
    
    func testAddMember_DoesNotAddDuplicate() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let user = User(email: "user@example.com", displayName: "User")
        let member = WorkspaceMember()
        member.user = user
        workspace.members = [member]
        dataService.insert(workspace)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try workspaceRepository.addMember(to: workspace, user: user)
        
        // Then
        XCTAssertEqual(workspace.members?.count, 1)
    }
    
    func testRemoveMember() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let user = User(email: "user@example.com", displayName: "User")
        let member = WorkspaceMember()
        member.user = user
        workspace.members = [member]
        dataService.insert(workspace)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try workspaceRepository.removeMember(member, from: workspace)
        
        // Then
        XCTAssertEqual(workspace.members?.count, 0)
    }
    
    func testUpdateMemberRole() throws {
        // Given
        let member = WorkspaceMember(role: "member")
        dataService.insert(member)
        try dataService.save()
        
        // When
        try workspaceRepository.updateMemberRole(member, role: "admin")
        
        // Then
        XCTAssertEqual(member.role, "admin")
    }
    
    // MARK: - WorkspaceRepository Statistics Tests
    
    func testGetWorkspaceStats() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let owner = User(email: "owner@example.com", displayName: "Owner")
        workspace.owner = owner
        
        let project1 = Project(name: "Project 1", status: "active")
        let project2 = Project(name: "Project 2", status: "active")
        let project3 = Project(name: "Project 3", status: "completed")
        project1.workspace = workspace
        project2.workspace = workspace
        project3.workspace = workspace
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        let task4 = Task(title: "Task 4")
        task1.status = "todo"
        task2.status = "done"
        task3.status = "done"
        task4.status = "inProgress"
        task4.dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) // Overdue
        
        project1.tasks = [task1, task2]
        project2.tasks = [task3]
        project3.tasks = [task4]
        
        let member = WorkspaceMember()
        workspace.members = [member]
        
        dataService.insert(workspace)
        try dataService.save()
        
        // When
        let stats = try workspaceRepository.getWorkspaceStats(workspaceId: workspace.id)
        
        // Then
        XCTAssertEqual(stats.totalProjects, 3)
        XCTAssertEqual(stats.activeProjects, 2)
        XCTAssertEqual(stats.completedProjects, 1)
        XCTAssertEqual(stats.totalTasks, 4)
        XCTAssertEqual(stats.completedTasks, 2)
        XCTAssertEqual(stats.overdueTasks, 1)
        XCTAssertEqual(stats.totalMembers, 1)
        XCTAssertEqual(stats.taskCompletionRate, 50.0)
    }
}
