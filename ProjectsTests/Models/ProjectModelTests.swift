//
//  ProjectModelTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for Project Model
//

import XCTest
@testable import Projects

@MainActor
final class ProjectModelTests: XCTestCase {
    
    // MARK: - Project Initialization Tests
    
    func testProject_Initialization_WithDefaultValues() {
        // Given & When
        let project = Project(name: "Test Project")
        
        // Then
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertNil(project.projectDescription)
        XCTAssertEqual(project.color, "#4ECDC4")
        XCTAssertEqual(project.icon, "folder.fill")
        XCTAssertEqual(project.status, "active")
        XCTAssertFalse(project.isArchived)
        XCTAssertNil(project.startDate)
        XCTAssertNil(project.dueDate)
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.createdAt)
        XCTAssertNotNil(project.updatedAt)
    }
    
    func testProject_Initialization_WithCustomValues() {
        // Given
        let name = "Custom Project"
        let description = "Project description"
        let color = "#FF6B6B"
        let icon = "star.fill"
        let status = "completed"
        let isArchived = false
        let startDate = Date()
        let dueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        
        // When
        let project = Project(
            name: name,
            projectDescription: description,
            color: color,
            icon: icon,
            status: status,
            isArchived: isArchived,
            startDate: startDate,
            dueDate: dueDate
        )
        
        // Then
        XCTAssertEqual(project.name, name)
        XCTAssertEqual(project.projectDescription, description)
        XCTAssertEqual(project.color, color)
        XCTAssertEqual(project.icon, icon)
        XCTAssertEqual(project.status, status)
        XCTAssertFalse(project.isArchived)
        XCTAssertEqual(project.startDate, startDate)
        XCTAssertEqual(project.dueDate, dueDate)
    }
    
    func testProject_UniqueID() {
        // Given & When
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        
        // Then
        XCTAssertNotEqual(project1.id, project2.id)
    }
    
    // MARK: - Project Status Extension Tests
    
    func testProjectStatusEnum_AllCases() {
        // Then
        XCTAssertEqual(Project.Status.allCases.count, 4)
        XCTAssertEqual(Project.Status.active, .active)
        XCTAssertEqual(Project.Status.paused, .paused)
        XCTAssertEqual(Project.Status.completed, .completed)
        XCTAssertEqual(Project.Status.archived, .archived)
    }
    
    func testProjectStatus_RawValues() {
        // Then
        XCTAssertEqual(Project.Status.active.rawValue, "Active")
        XCTAssertEqual(Project.Status.paused.rawValue, "Paused")
        XCTAssertEqual(Project.Status.completed.rawValue, "Completed")
        XCTAssertEqual(Project.Status.archived.rawValue, "Archived")
    }
    
    func testProjectStatus_Colors() {
        // Then
        XCTAssertEqual(Project.Status.active.color, "#00BA88")
        XCTAssertEqual(Project.Status.paused.color, "#FFB020")
        XCTAssertEqual(Project.Status.completed.color, "#2D5BFF")
        XCTAssertEqual(Project.Status.archived.color, "#95A5A6")
    }
    
    func testProjectStatus_Icons() {
        // Then
        XCTAssertEqual(Project.Status.active.icon, "play.circle.fill")
        XCTAssertEqual(Project.Status.paused.icon, "pause.circle.fill")
        XCTAssertEqual(Project.Status.completed.icon, "checkmark.circle.fill")
        XCTAssertEqual(Project.Status.archived.icon, "archivebox.fill")
    }
    
    // MARK: - Project Computed Properties Tests
    
    func testProject_TaskCount_WhenNoTasks() {
        // Given
        let project = Project(name: "Test Project")
        
        // Then
        XCTAssertEqual(project.taskCount, 0)
    }
    
    func testProject_TaskCount_WhenTasksExist() {
        // Given
        let project = Project(name: "Test Project")
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        project.tasks = [task1, task2, task3]
        
        // Then
        XCTAssertEqual(project.taskCount, 3)
    }
    
    func testProject_CompletedTaskCount_WhenNoTasks() {
        // Given
        let project = Project(name: "Test Project")
        
        // Then
        XCTAssertEqual(project.completedTaskCount, 0)
    }
    
    func testProject_CompletedTaskCount_WhenSomeTasksCompleted() {
        // Given
        let project = Project(name: "Test Project")
        let task1 = Task(title: "Task 1")
        task1.status = "done"
        let task2 = Task(title: "Task 2")
        task2.status = "todo"
        let task3 = Task(title: "Task 3")
        task3.status = "done"
        project.tasks = [task1, task2, task3]
        
        // Then
        XCTAssertEqual(project.completedTaskCount, 2)
    }
    
    func testProject_ProgressPercentage_WhenNoTasks() {
        // Given
        let project = Project(name: "Test Project")
        
        // Then
        XCTAssertEqual(project.progressPercentage, 0)
    }
    
    func testProject_ProgressPercentage_WhenAllTasksCompleted() {
        // Given
        let project = Project(name: "Test Project")
        let task1 = Task(title: "Task 1")
        task1.status = "done"
        let task2 = Task(title: "Task 2")
        task2.status = "done"
        project.tasks = [task1, task2]
        
        // Then
        XCTAssertEqual(project.progressPercentage, 100.0)
    }
    
    func testProject_ProgressPercentage_WhenHalfTasksCompleted() {
        // Given
        let project = Project(name: "Test Project")
        let task1 = Task(title: "Task 1")
        task1.status = "done"
        let task2 = Task(title: "Task 2")
        task2.status = "todo"
        project.tasks = [task1, task2]
        
        // Then
        XCTAssertEqual(project.progressPercentage, 50.0)
    }
    
    func testProject_ProgressPercentage_WithVariousCompletion() {
        // Given
        let project = Project(name: "Test Project")
        var tasks: [Task] = []
        for i in 0..<10 {
            let task = Task(title: "Task \(i)")
            if i < 7 {
                task.status = "done"
            }
            tasks.append(task)
        }
        project.tasks = tasks
        
        // Then
        XCTAssertEqual(project.progressPercentage, 70.0)
    }
    
    // MARK: - Project Relationship Tests
    
    func testProject_WorkspaceRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        
        // When
        project.workspace = workspace
        
        // Then
        XCTAssertEqual(project.workspace, workspace)
    }
    
    func testProject_TasksRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        
        // When
        project.tasks = [task1, task2]
        
        // Then
        XCTAssertEqual(project.tasks?.count, 2)
    }
    
    func testProject_BoardColumnsRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let column1 = BoardColumn(name: "To Do")
        let column2 = BoardColumn(name: "Done")
        
        // When
        project.boardColumns = [column1, column2]
        
        // Then
        XCTAssertEqual(project.boardColumns?.count, 2)
    }
    
    func testProject_MembersRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let member1 = ProjectMember()
        member1.user = user1
        let member2 = ProjectMember()
        member2.user = user2
        
        // When
        project.members = [member1, member2]
        
        // Then
        XCTAssertEqual(project.members?.count, 2)
    }
    
    // MARK: - Project Advanced Features Tests
    
    func testProject_CustomFieldDefinitionsRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let field1 = CustomFieldDefinition(name: "Priority", fieldType: "dropdown")
        let field2 = CustomFieldDefinition(name: "Story Points", fieldType: "number")
        
        // When
        project.customFieldDefinitions = [field1, field2]
        
        // Then
        XCTAssertEqual(project.customFieldDefinitions?.count, 2)
    }
    
    func testProject_TemplatesRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let template1 = TaskTemplate(name: "Bug Template", category: "bug")
        let template2 = TaskTemplate(name: "Feature Template", category: "feature")
        
        // When
        project.templates = [template1, template2]
        
        // Then
        XCTAssertEqual(project.templates?.count, 2)
    }
    
    func testProject_InvitationsRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let invitation1 = Invitation(email: "user1@example.com", inviteType: "project")
        let invitation2 = Invitation(email: "user2@example.com", inviteType: "project")
        
        // When
        project.invitations = [invitation1, invitation2]
        
        // Then
        XCTAssertEqual(project.invitations?.count, 2)
    }
    
    func testProject_SavedViewsRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let view1 = SavedView(name: "My Tasks", viewType: "list")
        let view2 = SavedView(name: "Board View", viewType: "board")
        
        // When
        project.savedViews = [view1, view2]
        
        // Then
        XCTAssertEqual(project.savedViews?.count, 2)
    }
}
