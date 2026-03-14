//
//  Label.swift
//  Projects
//
//  TaskFlow - Label Model
//

import Foundation
import SwiftData

@Model
final class Label {
    @Attribute(.unique) var id: String
    var name: String
    var color: String
    var icon: String?
    var order: Int
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify) var workspace: Workspace?
    @Relationship(deleteRule: .nullify) var taskLabels: [TaskLabel]?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "#2D5BFF",
        icon: String? = nil,
        order: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.order = order
        self.createdAt = createdAt
    }
}

// MARK: - Default Labels
extension Label {
    static func defaultLabels() -> [Label] {
        [
            Label(name: "Bug", color: "#FF4757", icon: "ladybug.fill"),
            Label(name: "Feature", color: "#2D5BFF", icon: "star.fill"),
            Label(name: "Enhancement", color: "#00BA88", icon: "sparkles"),
            Label(name: "Documentation", color: "#95A5A6", icon: "doc.text.fill"),
            Label(name: "Testing", color: "#FFB020", icon: "checkmark.seal.fill"),
            Label(name: "Design", color: "#A855F7", icon: "paintbrush.fill"),
            Label(name: "Research", color: "#45B7D1", icon: "magnifyingglass"),
            Label(name: "Meeting", color: "#FF6B6B", icon: "person.2.fill")
        ]
    }
}
