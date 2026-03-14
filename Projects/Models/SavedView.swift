//
//  SavedView.swift
//  Projects
//
//  TaskFlow - Saved View Model
//

import Foundation
import SwiftData

@Model
final class SavedView {
    @Attribute(.unique) var id: String
    var name: String
    var viewType: String
    var filters: String?
    var sortOrder: String?
    var groupBy: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify) var project: Project?
    @Relationship(deleteRule: .nullify) var user: User?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        viewType: String = "board",
        filters: String? = nil,
        sortOrder: String? = nil,
        groupBy: String? = nil,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.viewType = viewType
        self.filters = filters
        self.sortOrder = sortOrder
        self.groupBy = groupBy
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - View Type Extension
extension SavedView {
    enum ViewType: String, CaseIterable, Identifiable {
        case board = "Board"
        case list = "List"
        case timeline = "Timeline"
        case calendar = "Calendar"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .board: return "square.grid.2x2.fill"
            case .list: return "list.bullet"
            case .timeline: return "timeline"
            case .calendar: return "calendar"
            }
        }
    }
}
