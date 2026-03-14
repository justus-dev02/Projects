//
//  User.swift
//  Projects
//
//  TaskFlow - User Model
//

import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var avatarColor: String
    var role: String
    var isLocalUser: Bool
    var createdAt: Date
    var lastActiveAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var workspaces: [Workspace]?
    @Relationship(deleteRule: .nullify) var ownedWorkspaces: [Workspace]?
    @Relationship(deleteRule: .nullify) var tasks: [Task]?
    @Relationship(deleteRule: .nullify) var comments: [Comment]?
    @Relationship(deleteRule: .cascade) var notifications: [NotificationModel]?
    
    init(
        id: String = UUID().uuidString,
        email: String,
        displayName: String,
        avatarColor: String = User.generateRandomColor(),
        role: String = "member",
        isLocalUser: Bool = true,
        createdAt: Date = Date(),
        lastActiveAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarColor = avatarColor
        self.role = role
        self.isLocalUser = isLocalUser
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    static func generateRandomColor() -> String {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        return colors.randomElement() ?? "#4ECDC4"
    }
}

// MARK: - User Role Extension
extension User {
    enum Role: String, CaseIterable, Identifiable {
        case owner = "Owner"
        case admin = "Admin"
        case member = "Member"
        case guest = "Guest"
        case viewer = "Viewer"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .owner: return "crown.fill"
            case .admin: return "star.fill"
            case .member: return "person.fill"
            case .guest: return "person.badge.plus"
            case .viewer: return "eye.fill"
            }
        }
        
        var canEdit: Bool {
            [.owner, .admin, .member].contains(self)
        }
        
        var canDelete: Bool {
            [.owner, .admin].contains(self)
        }
        
        var canInvite: Bool {
            [.owner, .admin].contains(self)
        }
    }
}
