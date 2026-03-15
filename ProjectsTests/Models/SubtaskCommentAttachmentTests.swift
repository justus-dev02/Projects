//
//  SubtaskCommentAttachmentTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for Subtask, Comment, and Attachment Models
//

import XCTest
@testable import Projects

@MainActor
final class SubtaskCommentAttachmentTests: XCTestCase {
    
    // MARK: - Subtask Tests
    
    func testSubtask_Initialization_WithDefaultValues() {
        // Given & When
        let subtask = Subtask(title: "Test Subtask")
        
        // Then
        XCTAssertEqual(subtask.title, "Test Subtask")
        XCTAssertFalse(subtask.isCompleted)
        XCTAssertEqual(subtask.order, 0)
        XCTAssertNil(subtask.completedAt)
        XCTAssertNotNil(subtask.id)
        XCTAssertNotNil(subtask.createdAt)
    }
    
    func testSubtask_Initialization_WithCustomValues() {
        // Given
        let title = "Custom Subtask"
        let isCompleted = true
        let order = 5
        let completedAt = Date()
        
        // When
        let subtask = Subtask(
            title: title,
            isCompleted: isCompleted,
            order: order,
            completedAt: completedAt
        )
        
        // Then
        XCTAssertEqual(subtask.title, title)
        XCTAssertTrue(subtask.isCompleted)
        XCTAssertEqual(subtask.order, order)
        XCTAssertEqual(subtask.completedAt, completedAt)
    }
    
    func testSubtask_UniqueID() {
        // Given & When
        let subtask1 = Subtask(title: "Subtask 1")
        let subtask2 = Subtask(title: "Subtask 2")
        
        // Then
        XCTAssertNotEqual(subtask1.id, subtask2.id)
    }
    
    func testSubtask_TaskRelationship() {
        // Given
        let task = Task(title: "Parent Task")
        let subtask = Subtask(title: "Child Subtask")
        
        // When
        subtask.task = task
        
        // Then
        XCTAssertEqual(subtask.task, task)
    }
    
    // MARK: - Comment Tests
    
    func testComment_Initialization_WithDefaultValues() {
        // Given & When
        let comment = Comment(content: "Test Comment")
        
        // Then
        XCTAssertEqual(comment.content, "Test Comment")
        XCTAssertFalse(comment.isEdited)
        XCTAssertNotNil(comment.id)
        XCTAssertNotNil(comment.createdAt)
        XCTAssertNotNil(comment.updatedAt)
    }
    
    func testComment_Initialization_WithCustomValues() {
        // Given
        let content = "Edited Comment"
        let isEdited = true
        let createdAt = Date().addingTimeInterval(-3600)
        let updatedAt = Date()
        
        // When
        let comment = Comment(
            content: content,
            isEdited: isEdited,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        
        // Then
        XCTAssertEqual(comment.content, content)
        XCTAssertTrue(comment.isEdited)
        XCTAssertEqual(comment.createdAt, createdAt)
        XCTAssertEqual(comment.updatedAt, updatedAt)
    }
    
    func testComment_UniqueID() {
        // Given & When
        let comment1 = Comment(content: "Comment 1")
        let comment2 = Comment(content: "Comment 2")
        
        // Then
        XCTAssertNotEqual(comment1.id, comment2.id)
    }
    
    func testComment_AuthorRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let comment = Comment(content: "Test Comment")
        
        // When
        comment.author = user
        
        // Then
        XCTAssertEqual(comment.author, user)
    }
    
    func testComment_TaskRelationship() {
        // Given
        let task = Task(title: "Test Task")
        let comment = Comment(content: "Test Comment")
        
        // When
        comment.task = task
        
        // Then
        XCTAssertEqual(comment.task, task)
    }
    
    // MARK: - Attachment Tests
    
    func testAttachment_Initialization_WithDefaultValues() {
        // Given & When
        let attachment = Attachment(
            fileName: "test.pdf",
            fileSize: 1024,
            mimeType: "application/pdf"
        )
        
        // Then
        XCTAssertEqual(attachment.fileName, "test.pdf")
        XCTAssertEqual(attachment.fileSize, 1024)
        XCTAssertEqual(attachment.mimeType, "application/pdf")
        XCTAssertNil(attachment.url)
        XCTAssertNil(attachment.thumbnailUrl)
        XCTAssertNotNil(attachment.id)
        XCTAssertNotNil(attachment.createdAt)
    }
    
    func testAttachment_Initialization_WithCustomValues() {
        // Given
        let fileName = "image.png"
        let fileSize: Int64 = 2048
        let mimeType = "image/png"
        let url = "https://example.com/image.png"
        let thumbnailUrl = "https://example.com/thumb.png"
        let createdAt = Date().addingTimeInterval(-3600)
        
        // When
        let attachment = Attachment(
            fileName: fileName,
            fileSize: fileSize,
            mimeType: mimeType,
            url: url,
            thumbnailUrl: thumbnailUrl,
            createdAt: createdAt
        )
        
        // Then
        XCTAssertEqual(attachment.fileName, fileName)
        XCTAssertEqual(attachment.fileSize, fileSize)
        XCTAssertEqual(attachment.mimeType, mimeType)
        XCTAssertEqual(attachment.url, url)
        XCTAssertEqual(attachment.thumbnailUrl, thumbnailUrl)
        XCTAssertEqual(attachment.createdAt, createdAt)
    }
    
    func testAttachment_UniqueID() {
        // Given & When
        let attachment1 = Attachment(fileName: "file1.pdf", fileSize: 1024, mimeType: "application/pdf")
        let attachment2 = Attachment(fileName: "file2.pdf", fileSize: 2048, mimeType: "application/pdf")
        
        // Then
        XCTAssertNotEqual(attachment1.id, attachment2.id)
    }
    
    func testAttachment_UploaderRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let attachment = Attachment(fileName: "test.pdf", fileSize: 1024, mimeType: "application/pdf")
        
        // When
        attachment.uploader = user
        
        // Then
        XCTAssertEqual(attachment.uploader, user)
    }
    
    func testAttachment_TaskRelationship() {
        // Given
        let task = Task(title: "Test Task")
        let attachment = Attachment(fileName: "test.pdf", fileSize: 1024, mimeType: "application/pdf")
        
        // When
        attachment.task = task
        
        // Then
        XCTAssertEqual(attachment.task, task)
    }
    
    // MARK: - TaskLabel Tests
    
    func testTaskLabel_Initialization() {
        // Given & When
        let taskLabel = TaskLabel()
        
        // Then
        XCTAssertNotNil(taskLabel.id)
        XCTAssertNotNil(taskLabel.createdAt)
    }
    
    func testTaskLabel_TaskRelationship() {
        // Given
        let task = Task(title: "Test Task")
        let taskLabel = TaskLabel()
        
        // When
        taskLabel.task = task
        
        // Then
        XCTAssertEqual(taskLabel.task, task)
    }
    
    func testTaskLabel_LabelRelationship() {
        // Given
        let label = Label(name: "Bug", color: "#FF4757")
        let taskLabel = TaskLabel()
        
        // When
        taskLabel.label = label
        
        // Then
        XCTAssertEqual(taskLabel.label, label)
    }
    
    // MARK: - TaskCollaborator Tests
    
    func testTaskCollaborator_Initialization_WithDefaultValues() {
        // Given & When
        let collaborator = TaskCollaborator()
        
        // Then
        XCTAssertNotNil(collaborator.id)
        XCTAssertEqual(collaborator.role, "contributor")
        XCTAssertNotNil(collaborator.joinedAt)
    }
    
    func testTaskCollaborator_Initialization_WithCustomValues() {
        // Given
        let role = "admin"
        let joinedAt = Date().addingTimeInterval(-3600)
        
        // When
        let collaborator = TaskCollaborator(role: role, joinedAt: joinedAt)
        
        // Then
        XCTAssertEqual(collaborator.role, role)
        XCTAssertEqual(collaborator.joinedAt, joinedAt)
    }
    
    func testTaskCollaborator_TaskRelationship() {
        // Given
        let task = Task(title: "Test Task")
        let collaborator = TaskCollaborator()
        
        // When
        collaborator.task = task
        
        // Then
        XCTAssertEqual(collaborator.task, task)
    }
    
    func testTaskCollaborator_UserRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let collaborator = TaskCollaborator()
        
        // When
        collaborator.user = user
        
        // Then
        XCTAssertEqual(collaborator.user, user)
    }
    
    // MARK: - ActivityLog Tests
    
    func testActivityLog_Initialization_WithDefaultValues() {
        // Given & When
        let activity = ActivityLog(action: "created", logDescription: "Task created")
        
        // Then
        XCTAssertNotNil(activity.id)
        XCTAssertEqual(activity.action, "created")
        XCTAssertEqual(activity.logDescription, "Task created")
        XCTAssertNil(activity.metadata)
        XCTAssertNotNil(activity.createdAt)
    }
    
    func testActivityLog_Initialization_WithCustomValues() {
        // Given
        let action = "updated"
        let logDescription = "Task updated"
        let metadata = "{\"field\": \"value\"}"
        let createdAt = Date().addingTimeInterval(-3600)
        
        // When
        let activity = ActivityLog(
            action: action,
            logDescription: logDescription,
            metadata: metadata,
            createdAt: createdAt
        )
        
        // Then
        XCTAssertEqual(activity.action, action)
        XCTAssertEqual(activity.logDescription, logDescription)
        XCTAssertEqual(activity.metadata, metadata)
        XCTAssertEqual(activity.createdAt, createdAt)
    }
    
    func testActivityLog_UserRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let activity = ActivityLog(action: "created", logDescription: "Task created")
        
        // When
        activity.user = user
        
        // Then
        XCTAssertEqual(activity.user, user)
    }
    
    func testActivityLog_TaskRelationship() {
        // Given
        let task = Task(title: "Test Task")
        let activity = ActivityLog(action: "created", logDescription: "Task created")
        
        // When
        activity.task = task
        
        // Then
        XCTAssertEqual(activity.task, task)
    }
    
    // MARK: - BoardColumn Tests
    
    func testBoardColumn_Initialization_WithDefaultValues() {
        // Given & When
        let column = BoardColumn(name: "To Do")
        
        // Then
        XCTAssertNotNil(column.id)
        XCTAssertEqual(column.name, "To Do")
        XCTAssertEqual(column.color, "#E6E9ED")
        XCTAssertEqual(column.order, 0)
        XCTAssertFalse(column.isCollapsed)
        XCTAssertNotNil(column.createdAt)
    }
    
    func testBoardColumn_Initialization_WithCustomValues() {
        // Given
        let name = "In Progress"
        let color = "#45B7D1"
        let order = 1
        let isCollapsed = true
        let createdAt = Date().addingTimeInterval(-3600)
        
        // When
        let column = BoardColumn(
            name: name,
            color: color,
            order: order,
            isCollapsed: isCollapsed,
            createdAt: createdAt
        )
        
        // Then
        XCTAssertEqual(column.name, name)
        XCTAssertEqual(column.color, color)
        XCTAssertEqual(column.order, order)
        XCTAssertTrue(column.isCollapsed)
        XCTAssertEqual(column.createdAt, createdAt)
    }
    
    func testBoardColumn_ProjectRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let column = BoardColumn(name: "To Do")
        
        // When
        column.project = project
        
        // Then
        XCTAssertEqual(column.project, project)
    }
    
    func testBoardColumn_TasksRelationship() {
        // Given
        let column = BoardColumn(name: "To Do")
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        
        // When
        column.tasks = [task1, task2]
        
        // Then
        XCTAssertEqual(column.tasks?.count, 2)
    }
    
    func testBoardColumn_DefaultColumns() {
        // When
        let columns = BoardColumn.defaultColumns()
        
        // Then
        XCTAssertEqual(columns.count, 4)
        XCTAssertEqual(columns[0].name, "To Do")
        XCTAssertEqual(columns[1].name, "In Progress")
        XCTAssertEqual(columns[2].name, "Review")
        XCTAssertEqual(columns[3].name, "Done")
    }
    
    // MARK: - ProjectMember Tests
    
    func testProjectMember_Initialization_WithDefaultValues() {
        // Given & When
        let member = ProjectMember()
        
        // Then
        XCTAssertNotNil(member.id)
        XCTAssertEqual(member.role, "member")
        XCTAssertNotNil(member.joinedAt)
    }
    
    func testProjectMember_Initialization_WithCustomValues() {
        // Given
        let role = "admin"
        let joinedAt = Date().addingTimeInterval(-3600)
        
        // When
        let member = ProjectMember(role: role, joinedAt: joinedAt)
        
        // Then
        XCTAssertEqual(member.role, role)
        XCTAssertEqual(member.joinedAt, joinedAt)
    }
    
    func testProjectMember_UserRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let member = ProjectMember()
        
        // When
        member.user = user
        
        // Then
        XCTAssertEqual(member.user, user)
    }
    
    func testProjectMember_ProjectRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let member = ProjectMember()
        
        // When
        member.project = project
        
        // Then
        XCTAssertEqual(member.project, project)
    }
}
