//
//  NotificationModel.swift
//  Projects
//
//  TaskFlow - Notification Model
//

import Foundation
import SwiftData

@Model
final class NotificationModel {
    @Attribute(.unique) var id: String
    var title: String
    var message: String
    var type: String
    var isRead: Bool
    var isActionable: Bool
    var actionUrl: String?
    var createdAt: Date
    var readAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var recipient: User?
    @Relationship(deleteRule: .nullify) var task: Task?
    @Relationship(deleteRule: .nullify) var project: Project?
    @Relationship(deleteRule: .nullify) var sender: User?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        type: String = "info",
        isRead: Bool = false,
        isActionable: Bool = false,
        actionUrl: String? = nil,
        createdAt: Date = Date(),
        readAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.isRead = isRead
        self.isActionable = isActionable
        self.actionUrl = actionUrl
        self.createdAt = createdAt
        self.readAt = readAt
    }
}

// MARK: - Notification Type Extension
extension NotificationModel {
    enum NotificationType: String, CaseIterable, Identifiable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case success = "Success"
        case mention = "Mention"
        case assignment = "Assignment"
        case dueDate = "Due Date"
        case comment = "Comment"
        case invitation = "Invitation"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .mention: return "at"
            case .assignment: return "person.badge.plus"
            case .dueDate: return "clock.fill"
            case .comment: return "message.fill"
            case .invitation: return "envelope.fill"
            }
        }
        
        var color: String {
            switch self {
            case .info: return "#2D5BFF"
            case .warning: return "#FFB020"
            case .error: return "#FF4757"
            case .success: return "#00BA88"
            case .mention: return "#A855F7"
            case .assignment: return "#45B7D1"
            case .dueDate: return "#FF6B6B"
            case .comment: return "#4ECDC4"
            case .invitation: return "#FFB020"
            }
        }
    }
}
