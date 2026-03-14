//
//  TaskDependency.swift
//  Projects
//
//  TaskFlow - Task Dependency Model
//

import Foundation
import SwiftData

/// Represents a dependency relationship between two tasks
@Model
final class TaskDependency {
    @Attribute(.unique) var id: String
    var dependencyType: String
    var lagDays: Int
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var predecessor: Task?
    @Relationship(deleteRule: .cascade) var successor: Task?
    
    init(
        id: String = UUID().uuidString,
        dependencyType: String = "finishToStart",
        lagDays: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.dependencyType = dependencyType
        self.lagDays = lagDays
        self.createdAt = createdAt
    }
}

// MARK: - Dependency Type
extension TaskDependency {
    enum DependencyType: String, CaseIterable, Identifiable {
        case finishToStart = "Finish to Start"
        case startToStart = "Start to Start"
        case finishToFinish = "Finish to Finish"
        case startToFinish = "Start to Finish"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .finishToStart: return "arrow.right"
            case .startToStart: return "arrow.right.circle"
            case .finishToFinish: return "arrow.right.square"
            case .startToFinish: return "arrow.triangle.2.circlepath"
            }
        }
        
        var description: String {
            switch self {
            case .finishToStart: return "Predecessor must finish before successor can start"
            case .startToStart: return "Predecessor must start before successor can start"
            case .finishToFinish: return "Predecessor must finish before successor can finish"
            case .startToFinish: return "Predecessor must start before successor can finish"
            }
        }
    }
}

// MARK: - Computed Properties
extension TaskDependency {
    var isBlocking: Bool {
        guard let predecessor = predecessor, let successor = successor else { return false }
        return !predecessor.isCompleted && dependencyType == "finishToStart"
    }
    
    var canStartSuccessor: Bool {
        guard let predecessor = predecessor else { return false }
        
        switch dependencyType {
        case "finishToStart":
            return predecessor.isCompleted
        case "startToStart":
            return predecessor.createdAt <= Date()
        case "finishToFinish":
            return predecessor.isCompleted
        case "startToFinish":
            return predecessor.createdAt <= Date()
        default:
            return false
        }
    }
}
