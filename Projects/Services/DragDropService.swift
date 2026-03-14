//
//  DragDropService.swift
//  Projects
//
//  TaskFlow - Drag & Drop Service for Kanban Board
//

import Foundation
import SwiftData
import Combine
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Drag Drop Service Protocol
protocol DragDropServiceProtocol {
    func moveTask(_ task: Task, to column: BoardColumn, at index: Int) throws
    func reorderTask(_ task: Task, in column: BoardColumn, from oldIndex: Int, to newIndex: Int) throws
    func swapTasks(_ task1: Task, _ task2: Task) throws
}

// MARK: - Drag Drop Data Transfer
struct DragDropTask: Transferable, Codable {
    let taskId: String
    let taskTitle: String
    let sourceColumnId: String
    let sourceIndex: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: DragDropTask.self, contentType: .taskDrag)
    }
}

// MARK: - Content Type Extension
extension UTType {
    static var taskDrag: UTType {
        UTType(exportedAs: "com.taskflow.task-drag")
    }
}

// MARK: - Drag Drop Service Implementation
@MainActor
final class DragDropService: DragDropServiceProtocol {
    private let dataService: DataService
    private let taskRepo: TaskRepository
    private let projectRepo: ProjectRepository
    
    init(
        dataService: DataService,
        taskRepo: TaskRepository? = nil,
        projectRepo: ProjectRepository? = nil
    ) {
        self.dataService = dataService
        self.taskRepo = taskRepo ?? TaskRepository(dataService: dataService)
        self.projectRepo = projectRepo ?? ProjectRepository(dataService: dataService)
    }
    
    // MARK: - Move Task Between Columns
    func moveTask(_ task: Task, to column: BoardColumn, at index: Int) throws {
        // Remove from old column
        if let oldColumn = task.column, oldColumn.id != column.id {
            task.column = nil
        }
        
        // Add to new column
        task.column = column
        task.order = index
        task.updatedAt = Date()
        
        // Update status based on column
        updateTaskStatusForColumn(task, column: column)
        
        // Reorder all tasks in the target column
        try reorderTasksInColumn(column, excluding: task)
        
        // Log activity
        try logTaskMove(task, from: task.column, to: column)
        
        try dataService.save()
    }
    
    // MARK: - Reorder Task Within Column
    func reorderTask(_ task: Task, in column: BoardColumn, from oldIndex: Int, to newIndex: Int) throws {
        task.order = newIndex
        task.updatedAt = Date()
        
        // Reorder all tasks in the column
        try reorderTasksInColumn(column, excluding: task)
        
        try dataService.save()
    }
    
    // MARK: - Swap Two Tasks
    func swapTasks(_ task1: Task, _ task2: Task) throws {
        guard task1.column == task2.column else {
            throw NSError(domain: "Tasks must be in the same column", code: 400)
        }
        
        let tempOrder = task1.order
        task1.order = task2.order
        task2.order = tempOrder
        
        task1.updatedAt = Date()
        task2.updatedAt = Date()
        
        try dataService.save()
    }
    
    // MARK: - Helper Methods
    private func updateTaskStatusForColumn(_ task: Task, column: BoardColumn) {
        // Map column name to task status
        let columnName = column.name.lowercased()
        
        if columnName.contains("to do") || columnName.contains("todo") || columnName.contains("backlog") {
            task.status = "todo"
        } else if columnName.contains("progress") || columnName.contains("doing") || columnName.contains("active") {
            task.status = "inProgress"
        } else if columnName.contains("review") || columnName.contains("testing") || columnName.contains("qa") {
            task.status = "review"
        } else if columnName.contains("done") || columnName.contains("complete") || columnName.contains("finished") {
            task.status = "done"
            task.completedAt = Date()
        }
    }
    
    private func reorderTasksInColumn(_ column: BoardColumn, excluding excludedTask: Task? = nil) throws {
        var tasks = column.tasks ?? []
        
        // Remove excluded task if present
        if let excluded = excludedTask {
            tasks.removeAll { $0.id == excluded.id }
        }
        
        // Sort by current order
        tasks.sort { $0.order < $1.order }
        
        // Re-insert excluded task at correct position
        if let excluded = excludedTask {
            let insertIndex = Swift.min(excluded.order, tasks.count)
            tasks.insert(excluded, at: insertIndex)
        }
        
        // Update order for all tasks
        for (index, task) in tasks.enumerated() {
            task.order = index
        }
    }
    
    private func logTaskMove(_ task: Task, from oldColumn: BoardColumn?, to newColumn: BoardColumn) throws {
        let activity = ActivityLog(
            action: "moved",
            logDescription: "Task moved from \(oldColumn?.name ?? "Unknown") to \(newColumn.name)"
        )
        activity.user = task.assignee
        task.activityLogs?.append(activity)
    }
}

// MARK: - Drop Direction
enum DropDirection {
    case before
    case after
    case on
    
    var icon: String {
        switch self {
        case .before: return "arrow.up"
        case .after: return "arrow.down"
        case .on: return "arrow.down.circle"
        }
    }
}

// MARK: - Drag State
enum DragState: Equatable {
    case inactive
    case pressing
    case dragging(translation: CGSize)
    
    var isActive: Bool {
        self != .inactive
    }
    
    var isDragging: Bool {
        if case .dragging = self {
            return true
        }
        return false
    }
}

// MARK: - Drop State
struct DropState: Equatable {
    var isOverTarget: Bool = false
    var dropDirection: DropDirection = .on
    var targetColumnId: String?
    var targetTaskId: String?
    
    var isActive: Bool {
        isOverTarget
    }
}
