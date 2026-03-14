//
//  RecurringTask.swift
//  Projects
//
//  TaskFlow - Recurring Task Model
//

import Foundation
import SwiftData

/// Model for recurring task patterns and instances
@Model
final class RecurringTask {
    @Attribute(.unique) var id: String
    var frequency: String
    var interval: Int
    var daysOfWeek: String?  // Comma-separated: "1,3,5" for Mon,Wed,Fri
    var dayOfMonth: Int?
    var monthOfYear: Int?
    var endDate: Date?
    var occurrences: Int?
    var createAheadDays: Int
    var isParentTask: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify) var parentTask: Task?
    @Relationship(deleteRule: .cascade) var instances: [Task]?
    @Relationship(deleteRule: .nullify) var project: Project?
    
    init(
        id: String = UUID().uuidString,
        frequency: String = "weekly",
        interval: Int = 1,
        daysOfWeek: String? = nil,
        dayOfMonth: Int? = nil,
        monthOfYear: Int? = nil,
        endDate: Date? = nil,
        occurrences: Int? = nil,
        createAheadDays: Int = 1,
        isParentTask: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.dayOfMonth = dayOfMonth
        self.monthOfYear = monthOfYear
        self.endDate = endDate
        self.occurrences = occurrences
        self.createAheadDays = createAheadDays
        self.isParentTask = isParentTask
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Recurring Frequency
extension RecurringTask {
    enum Frequency: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case weekly = "Weekly"
        case biweekly = "Bi-weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"
        case custom = "Custom"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .daily: return "sun.max"
            case .weekly, .biweekly: return "calendar"
            case .monthly: return "calendar.badge.plus"
            case .yearly: return "calendar.badge.clock"
            case .custom: return "gearshape"
            }
        }
    }
    
    enum DaysOfWeek: Int, CaseIterable {
        case sunday = 1
        case monday = 2
        case tuesday = 3
        case wednesday = 4
        case thursday = 5
        case friday = 6
        case saturday = 7
        
        var shortName: String {
            switch self {
            case .sunday: return "Sun"
            case .monday: return "Mon"
            case .tuesday: return "Tue"
            case .wednesday: return "Wed"
            case .thursday: return "Thu"
            case .friday: return "Fri"
            case .saturday: return "Sat"
            }
        }
    }
}

// MARK: - Computed Properties
extension RecurringTask {
    var frequencyDescription: String {
        switch Frequency(rawValue: frequency) {
        case .daily:
            return interval > 1 ? "Every \(interval) days" : "Daily"
        case .weekly:
            return interval > 1 ? "Every \(interval) weeks" : "Weekly"
        case .biweekly:
            return "Every 2 weeks"
        case .monthly:
            if let day = dayOfMonth {
                return "On day \(day) of each month"
            }
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .custom:
            return "Custom"
        case .none:
            return "Unknown"
        }
    }
    
    var nextOccurrenceDate: Date? {
        guard let lastInstance = instances?.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            return parentTask?.dueDate
        }
        
        return calculateNextDate(after: lastInstance.dueDate ?? lastInstance.createdAt)
    }
    
    var activeInstancesCount: Int {
        // FIXED: Removed the invalid `?` before `.count`
        instances?.filter { !$0.isCompleted }.count ?? 0
    }
    
    var completedInstancesCount: Int {
        // FIXED: Removed the invalid `?` before `.count`
        instances?.filter { $0.isCompleted }.count ?? 0
    }
}

// MARK: - Date Calculation
extension RecurringTask {
    func calculateNextDate(after date: Date?) -> Date {
        let baseDate = date ?? Date()
        var components = DateComponents()
        
        switch Frequency(rawValue: frequency) {
        case .daily:
            components.day = interval
        case .weekly:
            components.weekOfYear = interval
        case .biweekly:
            components.weekOfYear = 2
        case .monthly:
            components.month = interval
        case .yearly:
            components.year = interval
        case .custom:
            components.day = interval
        case .none:
            components.day = interval
        }
        
        return Calendar.current.date(byAdding: components, to: baseDate) ?? Date()
    }
    
    func shouldCreateNextInstance() -> Bool {
        // Check end date
        if let endDate = endDate, Date() > endDate {
            return false
        }
        
        // Check occurrences limit
        if let maxOccurrences = occurrences {
            let currentCount = instances?.count ?? 0
            if currentCount >= maxOccurrences {
                return false
            }
        }
        
        // Check if we need to create ahead
        guard let nextDate = nextOccurrenceDate else { return true }
        let daysUntilNext = Calendar.current.dateComponents([.day], from: Date(), to: nextDate).day ?? 0
        return daysUntilNext <= createAheadDays
    }
}
