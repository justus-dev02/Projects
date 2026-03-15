//
//  Message.swift
//  Projects
//
//  TaskFlow - Message Model for Workspace Chat
//

import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: String
    var content: String
    var messageType: String
    var isEdited: Bool
    var createdAt: Date
    var updatedAt: Date
    var readAt: Date?

    // Relationships
    @Relationship(deleteRule: .nullify) var sender: User?
    @Relationship(deleteRule: .cascade) var workspace: Workspace?
    @Relationship(deleteRule: .cascade) var attachments: [MessageAttachment]?
    @Relationship(deleteRule: .cascade) var reactions: [MessageReaction]?

    init(
        id: String = UUID().uuidString,
        content: String,
        messageType: String = "text",
        isEdited: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        readAt: Date? = nil
    ) {
        self.id = id
        self.content = content
        self.messageType = messageType
        self.isEdited = isEdited
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.readAt = readAt
    }
}

// MARK: - Message Attachment
@Model
final class MessageAttachment {
    @Attribute(.unique) var id: String
    var fileName: String
    var fileSize: Int64
    var mimeType: String
    var url: String?
    var thumbnailUrl: String?
    var createdAt: Date

    // Relationship
    @Relationship(deleteRule: .cascade) var message: Message?

    init(
        id: String = UUID().uuidString,
        fileName: String,
        fileSize: Int64,
        mimeType: String,
        url: String? = nil,
        thumbnailUrl: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.createdAt = createdAt
    }
}

// MARK: - Message Reaction
@Model
final class MessageReaction {
    @Attribute(.unique) var id: String
    var emoji: String
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade) var message: Message?
    @Relationship(deleteRule: .cascade) var user: User?

    init(
        id: String = UUID().uuidString,
        emoji: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

// MARK: - Message Type Extension
extension Message {
    enum MessageType: String, CaseIterable, Identifiable {
        case text = "text"
        case image = "image"
        case file = "file"
        case system = "system"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .text: return "message.fill"
            case .image: return "photo.fill"
            case .file: return "doc.fill"
            case .system: return "gearshape.fill"
            }
        }
    }
}

// MARK: - Message Computed Properties
extension Message {
    var isSystemMessage: Bool {
        messageType == "system"
    }

    var hasAttachments: Bool {
        !(attachments?.isEmpty ?? true)
    }

    var attachmentCount: Int {
        attachments?.count ?? 0
    }

    var reactionCount: Int {
        reactions?.count ?? 0
    }

    var shortContent: String {
        if content.count > 50 {
            return String(content.prefix(50)) + "..."
        }
        return content
    }
}
