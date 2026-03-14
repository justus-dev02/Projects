//
//  ProjectsTests.swift
//  ProjectsTests
//
//  TaskFlow - Unit Tests
//

import XCTest
@testable import Projects

final class ProjectsTests: XCTestCase {
    
    // MARK: - User Tests
    func testUserCreation() {
        let user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.role, "member")
        XCTAssertTrue(user.isLocalUser)
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(user.createdAt)
    }
    
    func testUserRandomColor() {
        let color = User.generateRandomColor()
        XCTAssertTrue(color.hasPrefix("#"))
        XCTAssertEqual(color.count, 7)
    }
    
    // MARK: - Workspace Tests
    func testWorkspaceCreation() {
        let workspace = Workspace(
            name: "Test Workspace",
            description: "Test Description",
            color: "#2D5BFF",
            icon: "briefcase.fill"
        )
        
        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertEqual(workspace.description, "Test Description")
        XCTAssertEqual(workspace.color, "#2D5BFF")
        XCTAssertEqual(workspace.icon, "briefcase.fill")
        XCTAssertFalse(workspace.isArchived)
    }
    
    func testWorkspaceStats() {
        let workspace = Workspace(name: "Test")
        
        XCTAssertEqual(workspace.projectCount, 0)
        XCTAssertEqual(workspace.memberCount, 0)
        XCTAssertEqual(workspace.activeProjectCount, 0)
        XCTAssertEqual(workspace.completedProjectCount, 0)
    }
    
    // MARK: - Project Tests
    func testProjectCreation() {
        let project = Project(
            name: "Test Project",
            description: "Test Description",
            color: "#4ECDC4",
            icon: "folder.fill",
            status: "active"
        )
        
        XCTAssertEqual(project.name, "Test Project")
        XCTAssertEqual(project.status, "active")
        XCTAssertFalse(project.isArchived)
    }
    
    func testProjectProgress() {
        let project = Project(name: "Test")
        
        XCTAssertEqual(project.progressPercentage, 0)
        
        // Simulate tasks
        let task1 = Task(title: "Task 1", status: "done")
        let task2 = Task(title: "Task 2", status: "todo")
        project.tasks = [task1, task2]
        
        XCTAssertEqual(project.progressPercentage, 50)
    }
    
    func testProjectStatusColors() {
        XCTAssertEqual(Project.Status.active.color, "#00BA88")
        XCTAssertEqual(Project.Status.paused.color, "#FFB020")
        XCTAssertEqual(Project.Status.completed.color, "#2D5BFF")
        XCTAssertEqual(Project.Status.archived.color, "#95A5A6")
    }
    
    // MARK: - Task Tests
    func testTaskCreation() {
        let task = Task(
            title: "Test Task",
            description: "Test Description",
            priority: "high",
            status: "todo"
        )
        
        XCTAssertEqual(task.title, "Test Task")
        XCTAssertEqual(task.priority, "high")
        XCTAssertEqual(task.status, "todo")
        XCTAssertEqual(task.order, 0)
    }
    
    func testTaskOverdue() {
        let taskNotOverdue = Task(title: "Task 1")
        XCTAssertFalse(taskNotOverdue.isOverdue)
        
        let taskOverdue = Task(
            title: "Task 2",
            dueDate: Date().addingTimeInterval(-86400)
        )
        XCTAssertTrue(taskOverdue.isOverdue)
        
        let taskCompleted = Task(
            title: "Task 3",
            status: "done",
            dueDate: Date().addingTimeInterval(-86400)
        )
        XCTAssertFalse(taskCompleted.isOverdue)
    }
    
    func testTaskDueDates() {
        let taskToday = Task(
            title: "Task Today",
            dueDate: Date()
        )
        XCTAssertTrue(taskToday.isDueToday)
        
        let taskTomorrow = Task(
            title: "Task Tomorrow",
            dueDate: Date().addingTimeInterval(86400)
        )
        XCTAssertTrue(taskTomorrow.isDueTomorrow)
    }
    
    func testTaskPriorityWeights() {
        XCTAssertEqual(Task.Priority.low.weight, 1)
        XCTAssertEqual(Task.Priority.medium.weight, 2)
        XCTAssertEqual(Task.Priority.high.weight, 3)
        XCTAssertEqual(Task.Priority.urgent.weight, 4)
    }
    
    func testTaskSubtaskProgress() {
        let task = Task(title: "Test Task")
        XCTAssertEqual(task.subtaskProgress, 0)
        
        let subtask1 = Subtask(title: "Subtask 1", isCompleted: true)
        let subtask2 = Subtask(title: "Subtask 2", isCompleted: false)
        let subtask3 = Subtask(title: "Subtask 3", isCompleted: true)
        task.subtasks = [subtask1, subtask2, subtask3]
        
        XCTAssertEqual(task.subtaskProgress, 2.0 / 3.0, accuracy: 0.01)
    }
    
    // MARK: - BoardColumn Tests
    func testDefaultBoardColumns() {
        let columns = BoardColumn.defaultColumns()
        
        XCTAssertEqual(columns.count, 4)
        XCTAssertEqual(columns[0].name, "To Do")
        XCTAssertEqual(columns[1].name, "In Progress")
        XCTAssertEqual(columns[2].name, "Review")
        XCTAssertEqual(columns[3].name, "Done")
    }
    
    // MARK: - Label Tests
    func testDefaultLabels() {
        let labels = Label.defaultLabels()
        
        XCTAssertEqual(labels.count, 8)
        
        let labelNames = labels.map { $0.name }
        XCTAssertTrue(labelNames.contains("Bug"))
        XCTAssertTrue(labelNames.contains("Feature"))
        XCTAssertTrue(labelNames.contains("Enhancement"))
        XCTAssertTrue(labelNames.contains("Documentation"))
    }
    
    // MARK: - Notification Tests
    func testNotificationCreation() {
        let notification = NotificationModel(
            title: "Test Notification",
            message: "Test Message",
            type: "info"
        )
        
        XCTAssertEqual(notification.title, "Test Notification")
        XCTAssertEqual(notification.message, "Test Message")
        XCTAssertEqual(notification.type, "info")
        XCTAssertFalse(notification.isRead)
    }
    
    func testNotificationTypes() {
        XCTAssertEqual(NotificationModel.NotificationType.info.icon, "info.circle.fill")
        XCTAssertEqual(NotificationModel.NotificationType.warning.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(NotificationModel.NotificationType.success.icon, "checkmark.circle.fill")
        XCTAssertEqual(NotificationModel.NotificationType.assignment.icon, "person.badge.plus")
    }
    
    // MARK: - Subtask Tests
    func testSubtaskCreation() {
        let subtask = Subtask(
            title: "Test Subtask",
            isCompleted: false,
            order: 0
        )
        
        XCTAssertEqual(subtask.title, "Test Subtask")
        XCTAssertFalse(subtask.isCompleted)
        XCTAssertEqual(subtask.order, 0)
        XCTAssertNil(subtask.completedAt)
    }
    
    func testSubtaskCompletion() {
        let subtask = Subtask(title: "Test Subtask")
        XCTAssertNil(subtask.completedAt)
        
        subtask.isCompleted = true
        // In real usage, completedAt would be set by the repository
    }
    
    // MARK: - Comment Tests
    func testCommentCreation() {
        let comment = Comment(
            content: "Test comment content",
            isEdited: false
        )
        
        XCTAssertEqual(comment.content, "Test comment content")
        XCTAssertFalse(comment.isEdited)
        XCTAssertNotNil(comment.createdAt)
    }
    
    // MARK: - SavedView Tests
    func testSavedViewCreation() {
        let savedView = SavedView(
            name: "My View",
            viewType: "board",
            isDefault: false
        )
        
        XCTAssertEqual(savedView.name, "My View")
        XCTAssertEqual(savedView.viewType, "board")
        XCTAssertFalse(savedView.isDefault)
    }
    
    func testViewTypes() {
        XCTAssertEqual(SavedView.ViewType.board.icon, "square.grid.2x2.fill")
        XCTAssertEqual(SavedView.ViewType.list.icon, "list.bullet")
        XCTAssertEqual(SavedView.ViewType.timeline.icon, "timeline")
        XCTAssertEqual(SavedView.ViewType.calendar.icon, "calendar")
    }
    
    // MARK: - Color Extension Tests
    func testColorFromHex() {
        let color = Color(hex: "#FF6B6B")
        XCTAssertNotNil(color)
    }
    
    // MARK: - Performance Tests
    func testPerformanceExample() throws {
        self.measure {
            // Create multiple tasks
            for _ in 0..<100 {
                _ = Task(title: "Performance Test Task")
            }
        }
    }
}
