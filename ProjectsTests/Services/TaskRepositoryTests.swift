//
//  TaskRepositoryTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for TaskRepository
//

import XCTest
@testable import Projects
import SwiftData

@MainActor
final class TaskRepositoryTests: XCTestCase {
    
    var repository: TaskRepository!
    var dataService: DataService!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            User.self,
            Workspace.self,
            Project.self,
            BoardColumn.self,
            Task.self,
            Subtask.self,
            Comment.self,
            Attachment.self,
            TaskLabel.self,
            Label.self,
            ActivityLog.self,
            TaskCollaborator.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = container.mainContext
        dataService = DataService(modelContext: modelContext)
        repository = TaskRepository(dataService: dataService)
    }
    
    override func tearDown() async throws {
        repository = nil
        dataService = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Create Task Tests
    
    func testCreateTask_Success() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        project.workspace = workspace
        let column = BoardColumn(name: "To Do")
        column.project = project
        dataService.insert(workspace)
        dataService.insert(project)
        dataService.insert(column)
        try dataService.save()
        
        // When
        let task = try repository.createTask(
            title: "New Task",
            taskDescription: "Task description",
            priority: "high",
            dueDate: Date(),
            estimatedHours: 5.0,
            column: column,
            project: project
        )
        
        // Then
        XCTAssertEqual(task.title, "New Task")
        XCTAssertEqual(task.taskDescription, "Task description")
        XCTAssertEqual(task.priority, "high")
        XCTAssertEqual(task.estimatedHours, 5.0)
        XCTAssertEqual(task.column, column)
        XCTAssertEqual(task.project, project)
        XCTAssertEqual(task.status, "todo")
    }
    
    func testCreateTask_WithAssignee() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        project.workspace = workspace
        let column = BoardColumn(name: "To Do")
        column.project = project
        let assignee = User(email: "assignee@example.com", displayName: "Assignee")
        dataService.insert(workspace)
        dataService.insert(project)
        dataService.insert(column)
        dataService.insert(assignee)
        try dataService.save()
        
        // When
        let task = try repository.createTask(
            title: "New Task",
            priority: "medium",
            column: column,
            project: project,
            assignee: assignee
        )
        
        // Then
        XCTAssertEqual(task.assignee, assignee)
    }
    
    func testCreateTask_SetsOrder() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        project.workspace = workspace
        let column = BoardColumn(name: "To Do")
        column.project = project
        let existingTask = Task(title: "Existing Task")
        existingTask.column = column
        existingTask.order = 0
        column.tasks = [existingTask]
        dataService.insert(workspace)
        dataService.insert(project)
        dataService.insert(column)
        try dataService.save()
        
        // When
        let task = try repository.createTask(
            title: "New Task",
            column: column,
            project: project
        )
        
        // Then
        XCTAssertEqual(task.order, 1)
    }
    
    func testCreateTask_CreatesActivityLog() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        project.workspace = workspace
        let column = BoardColumn(name: "To Do")
        column.project = project
        dataService.insert(workspace)
        dataService.insert(project)
        dataService.insert(column)
        try dataService.save()
        
        // When
        let task = try repository.createTask(
            title: "New Task",
            column: column,
            project: project
        )
        
        // Then
        XCTAssertEqual(task.activityLogs?.count, 1)
        XCTAssertEqual(task.activityLogs?.first?.action, "created")
    }
    
    // MARK: - Fetch Tasks Tests
    
    func testGetTaskWithDetails() throws {
        // Given
        let task = Task(title: "Test Task")
        dataService.insert(task)
        try dataService.save()
        
        // When
        let fetched = try repository.getTaskWithDetails(id: task.id)
        
        // Then
        XCTAssertEqual(fetched?.id, task.id)
        XCTAssertEqual(fetched?.title, "Test Task")
    }
    
    func testGetTaskWithDetails_NotFound() throws {
        // When
        let fetched = try repository.getTaskWithDetails(id: "nonexistent-id")
        
        // Then
        XCTAssertNil(fetched)
    }
    
    func testGetTasksForProject() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        project1.workspace = workspace
        project2.workspace = workspace
        dataService.insert(workspace)
        dataService.insert(project1)
        dataService.insert(project2)
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        task1.project = project1
        task2.project = project1
        task3.project = project2
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.getTasksForProject(projectId: project1.id)
        
        // Then
        XCTAssertEqual(tasks.count, 2)
    }
    
    func testGetTasksForColumn() throws {
        // Given
        let column1 = BoardColumn(name: "To Do")
        let column2 = BoardColumn(name: "Done")
        dataService.insert(column1)
        dataService.insert(column2)
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        task1.column = column1
        task2.column = column1
        task3.column = column2
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.getTasksForColumn(columnId: column1.id)
        
        // Then
        XCTAssertEqual(tasks.count, 2)
    }
    
    func testGetTasksForUser() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        dataService.insert(user1)
        dataService.insert(user2)
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        task1.assignee = user1
        task2.assignee = user1
        task3.assignee = user2
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.getTasksForUser(userId: user1.id)
        
        // Then
        XCTAssertEqual(tasks.count, 2)
    }
    
    func testGetMyTasks() throws {
        // Given
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(user)
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        task1.assignee = user
        task1.status = "todo"
        task2.assignee = user
        task2.status = "inProgress"
        task3.assignee = user
        task3.status = "done"
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.getMyTasks(userId: user.id)
        
        // Then
        XCTAssertEqual(tasks.count, 2) // Only non-done tasks
    }
    
    func testGetOverdueTasks() throws {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        let task1 = Task(title: "Overdue Task 1", dueDate: pastDate)
        let task2 = Task(title: "Overdue Task 2", dueDate: pastDate)
        let task3 = Task(title: "Future Task", dueDate: futureDate)
        let task4 = Task(title: "Completed Overdue", dueDate: pastDate)
        task4.status = "done"
        
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        dataService.insert(task4)
        try dataService.save()
        
        // When
        let tasks = try repository.getOverdueTasks()
        
        // Then
        XCTAssertEqual(tasks.count, 2) // Only incomplete overdue tasks
    }
    
    func testGetOverdueTasks_ForUser() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        dataService.insert(user1)
        dataService.insert(user2)
        
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        
        let task1 = Task(title: "Task 1", dueDate: pastDate)
        let task2 = Task(title: "Task 2", dueDate: pastDate)
        task1.assignee = user1
        task2.assignee = user2
        
        dataService.insert(task1)
        dataService.insert(task2)
        try dataService.save()
        
        // When
        let tasks = try repository.getOverdueTasks(userId: user1.id)
        
        // Then
        XCTAssertEqual(tasks.count, 1)
    }
    
    func testGetTasksByPriority() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        project.workspace = workspace
        dataService.insert(workspace)
        dataService.insert(project)
        
        let task1 = Task(title: "Task 1", priority: "high")
        let task2 = Task(title: "Task 2", priority: "high")
        let task3 = Task(title: "Task 3", priority: "low")
        task1.project = project
        task2.project = project
        task3.project = project
        
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.getTasksByPriority(projectId: project.id, priority: "high")
        
        // Then
        XCTAssertEqual(tasks.count, 2)
    }
    
    // MARK: - Update Task Tests
    
    func testUpdateTask_Title() throws {
        // Given
        let task = Task(title: "Original Title")
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.updateTask(task, title: "Updated Title")
        
        // Then
        XCTAssertEqual(task.title, "Updated Title")
    }
    
    func testUpdateTask_Description() throws {
        // Given
        let task = Task(title: "Test Task")
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.updateTask(task, taskDescription: "New Description")
        
        // Then
        XCTAssertEqual(task.taskDescription, "New Description")
    }
    
    func testUpdateTask_Status_ToDone() throws {
        // Given
        let task = Task(title: "Test Task")
        task.status = "todo"
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.updateTask(task, status: "done")
        
        // Then
        XCTAssertEqual(task.status, "done")
        XCTAssertNotNil(task.completedAt)
    }
    
    func testUpdateTask_Status_ToNotDone() throws {
        // Given
        let task = Task(title: "Test Task")
        task.status = "done"
        task.completedAt = Date()
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.updateTask(task, status: "inProgress")
        
        // Then
        XCTAssertEqual(task.status, "inProgress")
        // completedAt should remain set
    }
    
    func testUpdateTask_Priority() throws {
        // Given
        let task = Task(title: "Test Task")
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.updateTask(task, priority: "urgent")
        
        // Then
        XCTAssertEqual(task.priority, "urgent")
    }
    
    func testUpdateTask_DueDate() throws {
        // Given
        let task = Task(title: "Test Task")
        dataService.insert(task)
        try dataService.save()
        
        let newDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        
        // When
        try repository.updateTask(task, dueDate: newDueDate)
        
        // Then
        XCTAssertEqual(task.dueDate, newDueDate)
    }
    
    func testUpdateTask_UpdatesTimestamp() throws {
        // Given
        let task = Task(title: "Test Task")
        let originalUpdatedAt = task.updatedAt
        dataService.insert(task)
        try dataService.save()
        
        // When
        Thread.sleep(forTimeInterval: 0.1) // Ensure time difference
        try repository.updateTask(task, title: "Updated")
        
        // Then
        XCTAssertGreaterThan(task.updatedAt, originalUpdatedAt)
    }
    
    // MARK: - Move Task Tests
    
    func testMoveTask_ToNewColumn() throws {
        // Given
        let column1 = BoardColumn(name: "To Do")
        let column2 = BoardColumn(name: "Done")
        dataService.insert(column1)
        dataService.insert(column2)
        
        let task = Task(title: "Test Task")
        task.column = column1
        task.order = 0
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.moveTask(task, to: column2, order: 0)
        
        // Then
        XCTAssertEqual(task.column, column2)
    }
    
    func testMoveTask_ReordersTasks() throws {
        // Given
        let column = BoardColumn(name: "To Do")
        dataService.insert(column)
        
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        task1.column = column
        task1.order = 0
        task2.column = column
        task2.order = 1
        task3.column = column
        task3.order = 2
        column.tasks = [task1, task2, task3]
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        try repository.moveTask(task3, to: column, order: 0)
        
        // Then
        XCTAssertEqual(task3.order, 0)
    }
    
    // MARK: - Delete Task Tests
    
    func testDeleteTask_Success() throws {
        // Given
        let task = Task(title: "Test Task")
        dataService.insert(task)
        try dataService.save()
        
        // When
        try repository.deleteTask(task)
        
        // Then
        let fetched = try repository.getTaskWithDetails(id: task.id)
        XCTAssertNil(fetched)
    }
    
    // MARK: - Subtask Tests
    
    func testAddSubtask() throws {
        // Given
        let task = Task(title: "Parent Task")
        dataService.insert(task)
        try dataService.save()
        
        // When
        let subtask = try repository.addSubtask(to: task, title: "New Subtask")
        
        // Then
        XCTAssertEqual(subtask.title, "New Subtask")
        XCTAssertEqual(subtask.task, task)
        XCTAssertEqual(task.subtasks?.count, 1)
    }
    
    func testAddSubtask_SetsOrder() throws {
        // Given
        let task = Task(title: "Parent Task")
        let subtask1 = Subtask(title: "Subtask 1")
        subtask1.task = task
        subtask1.order = 0
        task.subtasks = [subtask1]
        dataService.insert(task)
        try dataService.save()
        
        // When
        let subtask2 = try repository.addSubtask(to: task, title: "Subtask 2")
        
        // Then
        XCTAssertEqual(subtask2.order, 1)
    }
    
    func testToggleSubtask_ToCompleted() throws {
        // Given
        let subtask = Subtask(title: "Test Subtask")
        subtask.isCompleted = false
        dataService.insert(subtask)
        try dataService.save()
        
        // When
        try repository.toggleSubtask(subtask)
        
        // Then
        XCTAssertTrue(subtask.isCompleted)
        XCTAssertNotNil(subtask.completedAt)
    }
    
    func testToggleSubtask_ToIncomplete() throws {
        // Given
        let subtask = Subtask(title: "Test Subtask")
        subtask.isCompleted = true
        subtask.completedAt = Date()
        dataService.insert(subtask)
        try dataService.save()
        
        // When
        try repository.toggleSubtask(subtask)
        
        // Then
        XCTAssertFalse(subtask.isCompleted)
        XCTAssertNil(subtask.completedAt)
    }
    
    func testDeleteSubtask() throws {
        // Given
        let subtask = Subtask(title: "Test Subtask")
        dataService.insert(subtask)
        try dataService.save()
        
        // When
        try repository.deleteSubtask(subtask)
        
        // Then
        let predicate = #Predicate<Subtask> { $0.id == subtask.id }
        let fetched = try dataService.fetchOne(Subtask.self, predicate: predicate)
        XCTAssertNil(fetched)
    }
    
    // MARK: - Comment Tests
    
    func testAddComment() throws {
        // Given
        let task = Task(title: "Test Task")
        let author = User(email: "author@example.com", displayName: "Author")
        dataService.insert(task)
        dataService.insert(author)
        try dataService.save()
        
        // When
        let comment = try repository.addComment(to: task, content: "Test Comment", author: author)
        
        // Then
        XCTAssertEqual(comment.content, "Test Comment")
        XCTAssertEqual(comment.author, author)
        XCTAssertEqual(comment.task, task)
        XCTAssertEqual(task.comments?.count, 1)
    }
    
    func testUpdateComment() throws {
        // Given
        let comment = Comment(content: "Original Content")
        dataService.insert(comment)
        try dataService.save()
        
        // When
        try repository.updateComment(comment, content: "Updated Content")
        
        // Then
        XCTAssertEqual(comment.content, "Updated Content")
        XCTAssertTrue(comment.isEdited)
    }
    
    func testDeleteComment() throws {
        // Given
        let comment = Comment(content: "Test Comment")
        dataService.insert(comment)
        try dataService.save()
        
        // When
        try repository.deleteComment(comment)
        
        // Then
        let predicate = #Predicate<Comment> { $0.id == comment.id }
        let fetched = try dataService.fetchOne(Comment.self, predicate: predicate)
        XCTAssertNil(fetched)
    }
    
    // MARK: - Label Tests
    
    func testAddLabel_ToTask() throws {
        // Given
        let task = Task(title: "Test Task")
        let label = Label(name: "Bug", color: "#FF4757")
        dataService.insert(task)
        dataService.insert(label)
        try dataService.save()
        
        // When
        try repository.addLabel(to: task, label: label)
        
        // Then
        XCTAssertEqual(task.labels?.count, 1)
        XCTAssertEqual(task.labels?.first?.label, label)
    }
    
    func testAddLabel_DoesNotAddDuplicate() throws {
        // Given
        let task = Task(title: "Test Task")
        let label = Label(name: "Bug", color: "#FF4757")
        let taskLabel = TaskLabel()
        taskLabel.label = label
        task.labels = [taskLabel]
        dataService.insert(task)
        dataService.insert(label)
        try dataService.save()
        
        // When
        try repository.addLabel(to: task, label: label)
        
        // Then
        XCTAssertEqual(task.labels?.count, 1) // Still 1, not 2
    }
    
    func testRemoveLabel() throws {
        // Given
        let task = Task(title: "Test Task")
        let label = Label(name: "Bug", color: "#FF4757")
        let taskLabel = TaskLabel()
        taskLabel.label = label
        task.labels = [taskLabel]
        dataService.insert(task)
        dataService.insert(label)
        try dataService.save()
        
        // When
        try repository.removeLabel(taskLabel, from: task)
        
        // Then
        XCTAssertEqual(task.labels?.count, 0)
    }
    
    // MARK: - Assignee Tests
    
    func testAssignTask_ToUser() throws {
        // Given
        let task = Task(title: "Test Task")
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(task)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try repository.assignTask(task, to: user)
        
        // Then
        XCTAssertEqual(task.assignee, user)
    }
    
    func testAssignTask_ToNil() throws {
        // Given
        let task = Task(title: "Test Task")
        let user = User(email: "user@example.com", displayName: "User")
        task.assignee = user
        dataService.insert(task)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try repository.assignTask(task, to: nil)
        
        // Then
        XCTAssertNil(task.assignee)
    }
    
    func testAddCollaborator() throws {
        // Given
        let task = Task(title: "Test Task")
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(task)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try repository.addCollaborator(to: task, user: user, role: "reviewer")
        
        // Then
        XCTAssertEqual(task.collaborators?.count, 1)
        XCTAssertEqual(task.collaborators?.first?.user, user)
        XCTAssertEqual(task.collaborators?.first?.role, "reviewer")
    }
    
    func testAddCollaborator_DoesNotAddDuplicate() throws {
        // Given
        let task = Task(title: "Test Task")
        let user = User(email: "user@example.com", displayName: "User")
        let collaborator = TaskCollaborator()
        collaborator.user = user
        task.collaborators = [collaborator]
        dataService.insert(task)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try repository.addCollaborator(to: task, user: user)
        
        // Then
        XCTAssertEqual(task.collaborators?.count, 1)
    }
    
    // MARK: - Activity Log Tests
    
    func testLogActivity() throws {
        // Given
        let task = Task(title: "Test Task")
        let user = User(email: "user@example.com", displayName: "User")
        dataService.insert(task)
        dataService.insert(user)
        try dataService.save()
        
        // When
        try repository.logActivity(
            for: task,
            action: "updated",
            logDescription: "Task was updated",
            user: user
        )
        
        // Then
        XCTAssertEqual(task.activityLogs?.count, 1)
        XCTAssertEqual(task.activityLogs?.first?.action, "updated")
        XCTAssertEqual(task.activityLogs?.first?.user, user)
    }
    
    // MARK: - Bulk Operations Tests
    
    func testBulkUpdateStatus() throws {
        // Given
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        try repository.bulkUpdateStatus(taskIds: [task1.id, task2.id], status: "done")
        
        // Then
        XCTAssertEqual(task1.status, "done")
        XCTAssertEqual(task2.status, "done")
        XCTAssertEqual(task3.status, "todo") // Unchanged
        XCTAssertNotNil(task1.completedAt)
        XCTAssertNotNil(task2.completedAt)
    }
    
    func testBulkDelete() throws {
        // Given
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        let task3 = Task(title: "Task 3")
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        try repository.bulkDelete(taskIds: [task1.id, task3.id])
        
        // Then
        let tasks = try repository.getAll()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].id, task2.id)
    }
    
    // MARK: - Search Tests
    
    func testSearchTasks_ByTitle() throws {
        // Given
        let task1 = Task(title: "Implement login feature")
        let task2 = Task(title: "Fix login bug")
        let task3 = Task(title: "Update documentation")
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.searchTasks(query: "login")
        
        // Then
        XCTAssertEqual(tasks.count, 2)
    }
    
    func testSearchTasks_ByDescription() throws {
        // Given
        let task1 = Task(title: "Task 1", taskDescription: "This is about authentication")
        let task2 = Task(title: "Task 2", taskDescription: "This is about database")
        let task3 = Task(title: "Task 3", taskDescription: nil)
        dataService.insert(task1)
        dataService.insert(task2)
        dataService.insert(task3)
        try dataService.save()
        
        // When
        let tasks = try repository.searchTasks(query: "authentication")
        
        // Then
        XCTAssertEqual(tasks.count, 1)
    }
    
    func testSearchTasks_ByTitle_WithProjectFilter() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        project1.workspace = workspace
        project2.workspace = workspace
        dataService.insert(workspace)
        dataService.insert(project1)
        dataService.insert(project2)
        
        let task1 = Task(title: "Task about login")
        let task2 = Task(title: "Task about login")
        task1.project = project1
        task2.project = project2
        dataService.insert(task1)
        dataService.insert(task2)
        try dataService.save()
        
        // When
        let tasks = try repository.searchTasks(query: "login", projectId: project1.id)
        
        // Then
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].project, project1)
    }
}
