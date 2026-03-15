//
//  TaskModelTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for Task Model
//

import XCTest
@testable import Projects

@MainActor
final class TaskModelTests: XCTestCase {
    
    // MARK: - Task Initialization Tests
    
    func testTaskInitialization_WithDefaultValues() {
        // Given
        let title = "Test Task"
        
        // When
        let task = Task(title: title)
        
        // Then
        XCTAssertEqual(task.title, title)
        XCTAssertEqual(task.status, "todo")
        XCTAssertEqual(task.priority, "medium")
        XCTAssertEqual(task.order, 0)
        XCTAssertNil(task.taskDescription)
        XCTAssertNil(task.dueDate)
        XCTAssertNil(task.completedAt)
        XCTAssertNil(task.estimatedHours)
        XCTAssertNil(task.actualHours)
        XCTAssertFalse(task.reminderEnabled)
        XCTAssertFalse(task.isRecurring)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(task.createdAt)
        XCTAssertNotNil(task.updatedAt)
    }
    
    func testTaskInitialization_WithCustomValues() {
        // Given
        let title = "Custom Task"
        let description = "Task description"
        let status = "inProgress"
        let priority = "high"
        let order = 5
        let dueDate = Date()
        let estimatedHours: Double = 10.5
        
        // When
        let task = Task(
            title: title,
            taskDescription: description,
            status: status,
            priority: priority,
            order: order,
            dueDate: dueDate,
            estimatedHours: estimatedHours,
            reminderEnabled: true,
            isRecurring: true
        )
        
        // Then
        XCTAssertEqual(task.title, title)
        XCTAssertEqual(task.taskDescription, description)
        XCTAssertEqual(task.status, status)
        XCTAssertEqual(task.priority, priority)
        XCTAssertEqual(task.order, order)
        XCTAssertEqual(task.dueDate, dueDate)
        XCTAssertEqual(task.estimatedHours, estimatedHours)
        XCTAssertTrue(task.reminderEnabled)
        XCTAssertTrue(task.isRecurring)
    }
    
    func testTask_UniqueID() {
        // Given & When
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        
        // Then
        XCTAssertNotEqual(task1.id, task2.id)
    }
    
    // MARK: - Task Status Extension Tests
    
    func testTaskStatusEnum_AllCases() {
        // Then
        XCTAssertEqual(Task.Status.allCases.count, 4)
        XCTAssertEqual(Task.Status.todo, .todo)
        XCTAssertEqual(Task.Status.inProgress, .inProgress)
        XCTAssertEqual(Task.Status.review, .review)
        XCTAssertEqual(Task.Status.done, .done)
    }
    
    func testTaskStatus_RawValues() {
        // Then
        XCTAssertEqual(Task.Status.todo.rawValue, "To Do")
        XCTAssertEqual(Task.Status.inProgress.rawValue, "In Progress")
        XCTAssertEqual(Task.Status.review.rawValue, "Review")
        XCTAssertEqual(Task.Status.done.rawValue, "Done")
    }
    
    func testTaskStatus_Colors() {
        // Then
        XCTAssertEqual(Task.Status.todo.color, "#95A5A6")
        XCTAssertEqual(Task.Status.inProgress.color, "#45B7D1")
        XCTAssertEqual(Task.Status.review.color, "#FFB020")
        XCTAssertEqual(Task.Status.done.color, "#00BA88")
    }
    
    func testTaskStatus_Icons() {
        // Then
        XCTAssertEqual(Task.Status.todo.icon, "circle")
        XCTAssertEqual(Task.Status.inProgress.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(Task.Status.review.icon, "eye.fill")
        XCTAssertEqual(Task.Status.done.icon, "checkmark.circle.fill")
    }
    
    // MARK: - Task Priority Extension Tests
    
    func testTaskPriorityEnum_AllCases() {
        // Then
        XCTAssertEqual(Task.Priority.allCases.count, 4)
        XCTAssertEqual(Task.Priority.low, .low)
        XCTAssertEqual(Task.Priority.medium, .medium)
        XCTAssertEqual(Task.Priority.high, .high)
        XCTAssertEqual(Task.Priority.urgent, .urgent)
    }
    
    func testTaskPriority_RawValues() {
        // Then
        XCTAssertEqual(Task.Priority.low.rawValue, "Low")
        XCTAssertEqual(Task.Priority.medium.rawValue, "Medium")
        XCTAssertEqual(Task.Priority.high.rawValue, "High")
        XCTAssertEqual(Task.Priority.urgent.rawValue, "Urgent")
    }
    
    func testTaskPriority_Colors() {
        // Then
        XCTAssertEqual(Task.Priority.low.color, "#95A5A6")
        XCTAssertEqual(Task.Priority.medium.color, "#45B7D1")
        XCTAssertEqual(Task.Priority.high.color, "#FFB020")
        XCTAssertEqual(Task.Priority.urgent.color, "#FF4757")
    }
    
    func testTaskPriority_Icons() {
        // Then
        XCTAssertEqual(Task.Priority.low.icon, "arrow.down")
        XCTAssertEqual(Task.Priority.medium.icon, "arrow.left.and.right")
        XCTAssertEqual(Task.Priority.high.icon, "arrow.up.right")
        XCTAssertEqual(Task.Priority.urgent.icon, "exclamationmark.triangle.fill")
    }
    
    func testTaskPriority_Weights() {
        // Then
        XCTAssertEqual(Task.Priority.low.weight, 1)
        XCTAssertEqual(Task.Priority.medium.weight, 2)
        XCTAssertEqual(Task.Priority.high.weight, 3)
        XCTAssertEqual(Task.Priority.urgent.weight, 4)
    }
    
    // MARK: - Task Computed Properties Tests
    
    func testTask_IsCompleted_WhenStatusIsDone() {
        // Given
        let task = Task(title: "Test")
        task.status = "done"
        
        // Then
        XCTAssertTrue(task.isCompleted)
    }
    
    func testTask_IsCompleted_WhenStatusIsNotDone() {
        // Given
        let task = Task(title: "Test")
        task.status = "todo"
        
        // Then
        XCTAssertFalse(task.isCompleted)
    }
    
    func testTask_IsOverdue_WhenDueDateIsPast() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = Task(title: "Test", dueDate: pastDate)
        task.status = "todo"
        
        // Then
        XCTAssertTrue(task.isOverdue)
    }
    
    func testTask_IsOverdue_WhenDueDateIsFuture() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = Task(title: "Test", dueDate: futureDate)
        task.status = "todo"
        
        // Then
        XCTAssertFalse(task.isOverdue)
    }
    
    func testTask_IsOverdue_WhenCompleted() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let task = Task(title: "Test", dueDate: pastDate)
        task.status = "done"
        
        // Then
        XCTAssertFalse(task.isOverdue)
    }
    
    func testTask_IsOverdue_WhenNoDueDate() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertFalse(task.isOverdue)
    }
    
    func testTask_IsDueToday() {
        // Given
        let today = Date()
        let task = Task(title: "Test", dueDate: today)
        
        // Then
        XCTAssertTrue(task.isDueToday)
    }
    
    func testTask_IsNotDueToday() {
        // Given
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = Task(title: "Test", dueDate: tomorrow)
        
        // Then
        XCTAssertFalse(task.isDueToday)
    }
    
    func testTask_IsDueTomorrow() {
        // Given
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let task = Task(title: "Test", dueDate: tomorrow)
        
        // Then
        XCTAssertTrue(task.isDueTomorrow)
    }
    
    func testTask_DaysUntilDue() {
        // Given
        let fiveDaysFromNow = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let task = Task(title: "Test", dueDate: fiveDaysFromNow)
        
        // Then
        XCTAssertEqual(task.daysUntilDue, 5)
    }
    
    func testTask_DaysUntilDue_WhenNoDueDate() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertNil(task.daysUntilDue)
    }
    
    func testTask_SubtaskProgress_WhenNoSubtasks() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertEqual(task.subtaskProgress, 0)
    }
    
    func testTask_SubtaskProgress_WhenAllCompleted() {
        // Given
        let task = Task(title: "Test")
        let subtask1 = Subtask(title: "Subtask 1", isCompleted: true)
        let subtask2 = Subtask(title: "Subtask 2", isCompleted: true)
        task.subtasks = [subtask1, subtask2]
        
        // Then
        XCTAssertEqual(task.subtaskProgress, 1.0)
    }
    
    func testTask_SubtaskProgress_WhenHalfCompleted() {
        // Given
        let task = Task(title: "Test")
        let subtask1 = Subtask(title: "Subtask 1", isCompleted: true)
        let subtask2 = Subtask(title: "Subtask 2", isCompleted: false)
        task.subtasks = [subtask1, subtask2]
        
        // Then
        XCTAssertEqual(task.subtaskProgress, 0.5)
    }
    
    func testTask_CommentCount() {
        // Given
        let task = Task(title: "Test")
        let comment1 = Comment(content: "Comment 1")
        let comment2 = Comment(content: "Comment 2")
        task.comments = [comment1, comment2]
        
        // Then
        XCTAssertEqual(task.commentCount, 2)
    }
    
    func testTask_CommentCount_WhenNoComments() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertEqual(task.commentCount, 0)
    }
    
    func testTask_AttachmentCount() {
        // Given
        let task = Task(title: "Test")
        let attachment1 = Attachment(fileName: "file1.pdf", fileSize: 1024, mimeType: "application/pdf")
        let attachment2 = Attachment(fileName: "file2.png", fileSize: 2048, mimeType: "image/png")
        task.attachments = [attachment1, attachment2]
        
        // Then
        XCTAssertEqual(task.attachmentCount, 2)
    }
    
    func testTask_AttachmentCount_WhenNoAttachments() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertEqual(task.attachmentCount, 0)
    }
    
    func testTask_CompletedSubtaskCount() {
        // Given
        let task = Task(title: "Test")
        let subtask1 = Subtask(title: "Subtask 1", isCompleted: true)
        let subtask2 = Subtask(title: "Subtask 2", isCompleted: false)
        let subtask3 = Subtask(title: "Subtask 3", isCompleted: true)
        task.subtasks = [subtask1, subtask2, subtask3]
        
        // Then
        XCTAssertEqual(task.completedSubtaskCount, 2)
    }
    
    func testTask_TotalSubtaskCount() {
        // Given
        let task = Task(title: "Test")
        let subtask1 = Subtask(title: "Subtask 1")
        let subtask2 = Subtask(title: "Subtask 2")
        task.subtasks = [subtask1, subtask2]
        
        // Then
        XCTAssertEqual(task.totalSubtaskCount, 2)
    }
    
    // MARK: - Task Dependency Tests
    
    func testTask_HasDependencies_WhenDependenciesExist() {
        // Given
        let task = Task(title: "Test")
        let dependency = TaskDependency()
        task.dependencies = [dependency]
        
        // Then
        XCTAssertTrue(task.hasDependencies)
    }
    
    func testTask_HasDependencies_WhenNoDependencies() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertFalse(task.hasDependencies)
    }
    
    func testTask_IsBlocked_WhenBlockingTaskNotCompleted() {
        // Given
        let task = Task(title: "Test")
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "todo"
        
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        task.dependencies = [dependency]
        
        // Then
        XCTAssertTrue(task.isBlocked)
    }
    
    func testTask_IsBlocked_WhenBlockingTaskCompleted() {
        // Given
        let task = Task(title: "Test")
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "done"
        
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        task.dependencies = [dependency]
        
        // Then
        XCTAssertFalse(task.isBlocked)
    }
    
    func testTask_CanStart_WhenNotBlocked() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertTrue(task.canStart)
    }
    
    func testTask_CanStart_WhenBlocked() {
        // Given
        let task = Task(title: "Test")
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "todo"
        
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        task.dependencies = [dependency]
        
        // Then
        XCTAssertFalse(task.canStart)
    }
    
    // MARK: - Task Reminder Tests
    
    func testTask_HasReminder_WhenEnabledAndDateSet() {
        // Given
        let task = Task(title: "Test")
        task.reminderEnabled = true
        task.reminderDate = Date()
        
        // Then
        XCTAssertTrue(task.hasReminder)
    }
    
    func testTask_HasReminder_WhenNotEnabled() {
        // Given
        let task = Task(title: "Test")
        task.reminderEnabled = false
        task.reminderDate = Date()
        
        // Then
        XCTAssertFalse(task.hasReminder)
    }
    
    func testTask_HasReminder_WhenNoDateSet() {
        // Given
        let task = Task(title: "Test")
        task.reminderEnabled = true
        task.reminderDate = nil
        
        // Then
        XCTAssertFalse(task.hasReminder)
    }
    
    func testTask_IsReminderDue_WhenReminderDateIsPast() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let task = Task(title: "Test")
        task.reminderEnabled = true
        task.reminderDate = pastDate
        task.status = "todo"
        
        // Then
        XCTAssertTrue(task.isReminderDue)
    }
    
    func testTask_IsReminderDue_WhenReminderDateIsFuture() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let task = Task(title: "Test")
        task.reminderEnabled = true
        task.reminderDate = futureDate
        task.status = "todo"
        
        // Then
        XCTAssertFalse(task.isReminderDue)
    }
    
    func testTask_IsReminderDue_WhenCompleted() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let task = Task(title: "Test")
        task.reminderEnabled = true
        task.reminderDate = pastDate
        task.status = "done"
        
        // Then
        XCTAssertFalse(task.isReminderDue)
    }
    
    // MARK: - Task Recurring Tests
    
    func testTask_HasRecurringPattern_WhenRecurringAndHasRecurringTask() {
        // Given
        let task = Task(title: "Test")
        task.isRecurring = true
        task.recurringTask = RecurringTask()
        
        // Then
        XCTAssertTrue(task.hasRecurringPattern)
    }
    
    func testTask_HasRecurringPattern_WhenNotRecurring() {
        // Given
        let task = Task(title: "Test")
        task.isRecurring = false
        
        // Then
        XCTAssertFalse(task.hasRecurringPattern)
    }
    
    func testTask_HasRecurringPattern_WhenNoRecurringTask() {
        // Given
        let task = Task(title: "Test")
        task.isRecurring = true
        task.recurringTask = nil
        
        // Then
        XCTAssertFalse(task.hasRecurringPattern)
    }
    
    func testTask_IsFromTemplate_WhenTemplateExists() {
        // Given
        let task = Task(title: "Test")
        task.template = TaskTemplate(name: "Template")
        
        // Then
        XCTAssertTrue(task.isFromTemplate)
    }
    
    func testTask_IsFromTemplate_WhenNoTemplate() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertFalse(task.isFromTemplate)
    }
    
    // MARK: - Task Description Tests
    
    func testTask_DependencyDescription_WhenBlocked() {
        // Given
        let task = Task(title: "Test")
        let predecessor1 = Task(title: "Predecessor 1")
        let predecessor2 = Task(title: "Predecessor 2")
        
        let dep1 = TaskDependency(dependencyType: "finishToStart")
        dep1.predecessor = predecessor1
        let dep2 = TaskDependency(dependencyType: "finishToStart")
        dep2.predecessor = predecessor2
        
        task.dependencies = [dep1, dep2]
        
        // Then
        XCTAssertEqual(task.dependencyDescription, "Blocked by 2 task(s)")
    }
    
    func testTask_DependencyDescription_WhenHasDependenciesButNotBlocked() {
        // Given
        let task = Task(title: "Test")
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "done"
        
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        task.dependencies = [dependency]
        
        // Then
        XCTAssertEqual(task.dependencyDescription, "Has dependencies")
    }
    
    func testTask_DependencyDescription_WhenNoDependencies() {
        // Given
        let task = Task(title: "Test")
        
        // Then
        XCTAssertEqual(task.dependencyDescription, "No dependencies")
    }
}
