//
//  BulkOperationsService.swift
//  Projects
//
//  TaskFlow - Bulk Operations for Tasks
//

import Foundation
import SwiftData
import Combine

// MARK: - Bulk Operations Service Protocol
protocol BulkOperationsServiceProtocol {
    func bulkDelete(tasks: [Task]) throws -> BulkOperationResult
    func bulkMove(tasks: [Task], to column: BoardColumn) throws -> BulkOperationResult
    func bulkUpdateStatus(tasks: [Task], status: String) throws -> BulkOperationResult
    func bulkUpdatePriority(tasks: [Task], priority: String) throws -> BulkOperationResult
    func bulkAssign(tasks: [Task], to user: User?) throws -> BulkOperationResult
    func bulkAddLabel(tasks: [Task], label: Label) throws -> BulkOperationResult
    func bulkRemoveLabel(tasks: [Task], label: Label) throws -> BulkOperationResult
    func bulkUpdateDueDate(tasks: [Task], date: Date?) throws -> BulkOperationResult
}

// MARK: - Bulk Operation Result
struct BulkOperationResult {
    let successCount: Int
    let failureCount: Int
    let errors: [Error]
    
    var isSuccess: Bool {
        failureCount == 0
    }
    
    var total: Int {
        successCount + failureCount
    }
}

// MARK: - Bulk Operations Service Implementation
@MainActor
final class BulkOperationsService: BulkOperationsServiceProtocol {
    private let dataService: DataService
    private let taskRepo: TaskRepository
    
    init(
        dataService: DataService,
        taskRepo: TaskRepository? = nil
    ) {
        self.dataService = dataService
        self.taskRepo = taskRepo ?? TaskRepository(dataService: dataService)
    }
    
    // MARK: - Bulk Delete
    func bulkDelete(tasks: [Task]) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                try taskRepo.deleteTask(task)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Move
    func bulkMove(tasks: [Task], to column: BoardColumn) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for (index, task) in tasks.enumerated() {
            do {
                try taskRepo.moveTask(task, to: column, order: index)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Update Status
    func bulkUpdateStatus(tasks: [Task], status: String) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                try taskRepo.updateTask(task, status: status)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Update Priority
    func bulkUpdatePriority(tasks: [Task], priority: String) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                try taskRepo.updateTask(task, priority: priority)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Assign
    func bulkAssign(tasks: [Task], to user: User?) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                try taskRepo.assignTask(task, to: user)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Add Label
    func bulkAddLabel(tasks: [Task], label: Label) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                try taskRepo.addLabel(to: task, label: label)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Remove Label
    func bulkRemoveLabel(tasks: [Task], label: Label) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                if let taskLabel = task.labels?.first(where: { $0.label?.id == label.id }) {
                    try taskRepo.removeLabel(taskLabel, from: task)
                }
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Update Due Date
    func bulkUpdateDueDate(tasks: [Task], date: Date?) throws -> BulkOperationResult {
        var successCount = 0
        var errors: [Error] = []
        
        for task in tasks {
            do {
                try taskRepo.updateTask(task, dueDate: date)
                successCount += 1
            } catch {
                errors.append(error)
            }
        }
        
        try dataService.save()
        
        return BulkOperationResult(
            successCount: successCount,
            failureCount: errors.count,
            errors: errors
        )
    }
    
    // MARK: - Bulk Create from Template
    func bulkCreateFromTemplate(
        template: TaskTemplate,
        count: Int,
        in project: Project,
        column: BoardColumn,
        startDate: Date
    ) throws -> [Task] {
        var createdTasks: [Task] = []
        
        for i in 0..<count {
            let taskDate = Calendar.current.date(byAdding: .day, value: i, to: startDate) ?? startDate
            
            let task = template.createTask(
                in: project,
                column: column,
                dueDate: taskDate
            )
            
            dataService.insert(task)
            createdTasks.append(task)
        }
        
        try dataService.save()
        return createdTasks
    }
}

// MARK: - Selection State for Bulk Operations
class BulkSelectionState: ObservableObject {
    @Published var isSelectionMode: Bool = false
    @Published var selectedTaskIds: Set<String> = []
    @Published var showBulkActions: Bool = false
    
    var hasSelection: Bool {
        !selectedTaskIds.isEmpty
    }
    
    var selectedCount: Int {
        selectedTaskIds.count
    }
    
    func toggleSelection(for taskId: String) {
        if selectedTaskIds.contains(taskId) {
            selectedTaskIds.remove(taskId)
        } else {
            selectedTaskIds.insert(taskId)
        }
        
        showBulkActions = hasSelection
    }
    
    func selectAll(taskIds: [String]) {
        selectedTaskIds = Set(taskIds)
        showBulkActions = hasSelection
    }
    
    func deselectAll() {
        selectedTaskIds.removeAll()
        showBulkActions = false
    }
    
    func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            deselectAll()
        }
    }
}
