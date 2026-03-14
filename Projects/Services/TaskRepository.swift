//
//  TaskRepository.swift
//  Projects
//
//  TaskFlow - Task Repository
//

import Foundation
import SwiftData

@MainActor
final class TaskRepository: BaseRepository<Task> {

    // MARK: - Fetch with Relations
    func getTaskWithDetails(id: String) throws -> Task? {
        let predicate = #Predicate<Task> { $0.id == id }
        return try dataService.fetchOne(Task.self, predicate: predicate)
    }

    func getTasksForProject(projectId: String) throws -> [Task] {
        let predicate = #Predicate<Task> { $0.project?.id == projectId }
        let sortDescriptor = [SortDescriptor<Task>(\.order)]
        return try dataService.fetch(Task.self, filter: sortDescriptor, predicate: predicate)
    }

    func getTasksForColumn(columnId: String) throws -> [Task] {
        let predicate = #Predicate<Task> { $0.column?.id == columnId }
        let sortDescriptor = [SortDescriptor<Task>(\.order)]
        return try dataService.fetch(Task.self, filter: sortDescriptor, predicate: predicate)
    }

    func getTasksForUser(userId: String) throws -> [Task] {
        let predicate = #Predicate<Task> { $0.assignee?.id == userId }
        return try dataService.fetch(Task.self, filter: [], predicate: predicate)
    }

    func getMyTasks(userId: String) throws -> [Task] {
        let predicate = #Predicate<Task> {
            $0.assignee?.id == userId && $0.status != "done"
        }
        let sortDescriptor = [SortDescriptor<Task>(\.dueDate, order: .forward)]
        return try dataService.fetch(Task.self, filter: sortDescriptor, predicate: predicate)
    }

    func getOverdueTasks(userId: String? = nil) throws -> [Task] {
        var predicate: Predicate<Task>?
        let now = Date()
        if let userId = userId {
            predicate = #Predicate<Task> {
                ($0.assignee?.id == userId) &&
                $0.dueDate != nil &&
                $0.dueDate! < now &&
                $0.status != "done"
            }
        } else {
            predicate = #Predicate<Task> {
                $0.dueDate != nil &&
                $0.dueDate! < now &&
                $0.status != "done"
            }
        }
        return try dataService.fetch(Task.self, filter: [], predicate: predicate)
    }
    
    func getTasksByPriority(projectId: String, priority: String) throws -> [Task] {
        let predicate = #Predicate<Task> {
            $0.project?.id == projectId && $0.priority == priority
        }
        return try dataService.fetch(Task.self, predicate: predicate)
    }
    
    // MARK: - Create
    func createTask(
        title: String,
        taskDescription: String? = nil,
        priority: String = "medium",
        dueDate: Date? = nil,
        estimatedHours: Double? = nil,
        column: BoardColumn,
        project: Project,
        assignee: User? = nil
    ) throws -> Task {
        let maxOrder = column.tasks?.max(by: { $0.order < $1.order })?.order ?? -1

        let task = Task(
            title: title,
            taskDescription: taskDescription,
            priority: priority,
            order: maxOrder + 1,
            dueDate: dueDate,
            estimatedHours: estimatedHours
        )
        task.column = column
        task.project = project
        task.assignee = assignee

        // Add to column
        column.tasks?.append(task)

        // Create activity log
        let activity = ActivityLog(
            action: "created",
            logDescription: "Task created: \(title)"
        )
        task.activityLogs?.append(activity)

        dataService.insert(task)
        try dataService.save()

        return task
    }

    // MARK: - Update
    func updateTask(
        _ task: Task,
        title: String? = nil,
        taskDescription: String? = nil,
        status: String? = nil,
        priority: String? = nil,
        dueDate: Date? = nil,
        estimatedHours: Double? = nil,
        actualHours: Double? = nil
    ) throws {
        if let title = title { task.title = title }
        if let taskDescription = taskDescription { task.taskDescription = taskDescription }
        if let status = status {
            task.status = status
            if status == "done" && task.completedAt == nil {
                task.completedAt = Date()
            }
        }
        if let priority = priority { task.priority = priority }
        if let dueDate = dueDate { task.dueDate = dueDate }
        if let estimatedHours = estimatedHours { task.estimatedHours = estimatedHours }
        if let actualHours = actualHours { task.actualHours = actualHours }
        task.updatedAt = Date()

        try dataService.save()
    }
    
    // MARK: - Move Task
    func moveTask(_ task: Task, to column: BoardColumn, order: Int) throws {
        // Remove from old column
        if task.column != nil {
            task.column = nil
        }

        // Add to new column
        task.column = column
        task.order = order
        task.updatedAt = Date()

        // Reorder tasks in new column
        try reorderTasksInColumn(column)

        try dataService.save()
    }
    
    func reorderTasksInColumn(_ column: BoardColumn) throws {
        let tasks = column.tasks?.sorted { $0.order < $1.order } ?? []
        for (index, task) in tasks.enumerated() {
            task.order = index
        }
        try dataService.save()
    }
    
    // MARK: - Delete
    func deleteTask(_ task: Task) throws {
        dataService.delete(task)
        try dataService.save()
    }
    
    // MARK: - Subtasks
    func addSubtask(to task: Task, title: String) throws -> Subtask {
        let maxOrder = task.subtasks?.max(by: { $0.order < $1.order })?.order ?? -1
        
        let subtask = Subtask(
            title: title,
            order: maxOrder + 1
        )
        subtask.task = task
        task.subtasks?.append(subtask)
        
        try dataService.save()
        return subtask
    }
    
    func toggleSubtask(_ subtask: Subtask) throws {
        subtask.isCompleted.toggle()
        subtask.completedAt = subtask.isCompleted ? Date() : nil
        try dataService.save()
    }
    
    func deleteSubtask(_ subtask: Subtask) throws {
        dataService.delete(subtask)
        try dataService.save()
    }
    
    // MARK: - Comments
    func addComment(to task: Task, content: String, author: User) throws -> Comment {
        let comment = Comment(content: content)
        comment.author = author
        comment.task = task
        task.comments?.append(comment)
        
        try dataService.save()
        return comment
    }
    
    func updateComment(_ comment: Comment, content: String) throws {
        comment.content = content
        comment.isEdited = true
        comment.updatedAt = Date()
        try dataService.save()
    }
    
    func deleteComment(_ comment: Comment) throws {
        dataService.delete(comment)
        try dataService.save()
    }
    
    // MARK: - Labels
    func addLabel(to task: Task, label: Label) throws {
        // Check if already has label
        let hasLabel = task.labels?.contains { $0.label?.id == label.id } == true
        if hasLabel { return }
        
        let taskLabel = TaskLabel()
        taskLabel.label = label
        task.labels?.append(taskLabel)
        
        try dataService.save()
    }
    
    func removeLabel(_ taskLabel: TaskLabel, from task: Task) throws {
        dataService.delete(taskLabel)
        try dataService.save()
    }
    
    // MARK: - Assignee
    func assignTask(_ task: Task, to user: User?) throws {
        task.assignee = user
        try dataService.save()
    }
    
    func addCollaborator(to task: Task, user: User, role: String = "contributor") throws {
        let isCollaborator = task.collaborators?.contains { $0.user?.id == user.id } == true
        if isCollaborator { return }
        
        let collaborator = TaskCollaborator(role: role)
        collaborator.user = user
        task.collaborators?.append(collaborator)
        
        try dataService.save()
    }
    
    // MARK: - Activity Log
    func logActivity(for task: Task, action: String, logDescription: String, user: User? = nil) throws {
        let activity = ActivityLog(
            action: action,
            logDescription: logDescription
        )
        activity.user = user
        task.activityLogs?.append(activity)

        try dataService.save()
    }
    
    // MARK: - Bulk Operations
    func bulkUpdateStatus(taskIds: [String], status: String) throws {
        for taskId in taskIds {
            if let task = try getById(taskId) {
                task.status = status
                if status == "done" {
                    task.completedAt = Date()
                }
                task.updatedAt = Date()
            }
        }
        try dataService.save()
    }
    
    func bulkDelete(taskIds: [String]) throws {
        for taskId in taskIds {
            if let task = try getById(taskId) {
                dataService.delete(task)
            }
        }
        try dataService.save()
    }
    
    // MARK: - Search
    func searchTasks(query: String, projectId: String? = nil) throws -> [Task] {
        var predicate: Predicate<Task>?

        if let projectId = projectId {
            predicate = #Predicate<Task> {
                ($0.title.localizedStandardContains(query) ||
                 ($0.taskDescription != nil && $0.taskDescription!.localizedStandardContains(query))) &&
                $0.project?.id == projectId
            }
        } else {
            predicate = #Predicate<Task> {
                $0.title.localizedStandardContains(query) ||
                ($0.taskDescription != nil && $0.taskDescription!.localizedStandardContains(query))
            }
        }

        return try dataService.fetch(Task.self, filter: [], predicate: predicate)
    }
}
