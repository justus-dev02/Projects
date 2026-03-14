//
//  Invitation.swift
//  Projects
//
//  TaskFlow - Invitation Model for User Management
//

import Foundation
import SwiftData

/// Model for workspace/project invitations
@Model
final class Invitation {
    @Attribute(.unique) var id: String
    var email: String
    var inviteType: String  // workspace, project
    var role: String
    var status: String  // pending, accepted, declined, expired
    var token: String
    var message: String?
    var expiresAt: Date
    var createdAt: Date
    var acceptedAt: Date?
    var declinedAt: Date?
    
    // Relationships
    @Relationship(deleteRule: .nullify) var inviter: User?
    @Relationship(deleteRule: .nullify) var workspace: Workspace?
    @Relationship(deleteRule: .nullify) var project: Project?
    @Relationship(deleteRule: .nullify) var invitee: User?
    
    init(
        id: String = UUID().uuidString,
        email: String,
        inviteType: String = "workspace",
        role: String = "member",
        status: String = "pending",
        token: String = "",
        message: String? = nil,
        expiresAt: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        createdAt: Date = Date(),
        acceptedAt: Date? = nil,
        declinedAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.inviteType = inviteType
        self.role = role
        self.status = status
        self.token = token.isEmpty ? UUID().uuidString : token
        self.message = message
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.acceptedAt = acceptedAt
        self.declinedAt = declinedAt
    }
}

// MARK: - Invitation Status
extension Invitation {
    enum Status: String, CaseIterable, Identifiable {
        case pending = "Pending"
        case accepted = "Accepted"
        case declined = "Declined"
        case expired = "Expired"
        case cancelled = "Cancelled"
        
        var id: String { rawValue }
        
        var color: String {
            switch self {
            case .pending: return "#FFB020"
            case .accepted: return "#00BA88"
            case .declined: return "#FF4757"
            case .expired: return "#95A5A6"
            case .cancelled: return "#95A5A6"
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .accepted: return "checkmark.circle.fill"
            case .declined: return "xmark.circle.fill"
            case .expired: return "exclamationmark.circle.fill"
            case .cancelled: return "slash.circle.fill"
            }
        }
    }
}

// MARK: - Invite Type
extension Invitation {
    enum InviteType: String, CaseIterable, Identifiable {
        case workspace = "Workspace"
        case project = "Project"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .workspace: return "briefcase.fill"
            case .project: return "folder.fill"
            }
        }
    }
}

// MARK: - Computed Properties
extension Invitation {
    var isExpired: Bool {
        Date() > expiresAt && status == "pending"
    }
    
    var isPending: Bool {
        status == "pending" && !isExpired
    }
    
    var canAccept: Bool {
        isPending
    }
    
    var inviteeDisplayName: String {
        invitee?.displayName ?? email
    }
    
    var targetName: String {
        if inviteType == "workspace" {
            return workspace?.name ?? "Unknown Workspace"
        } else {
            return project?.name ?? "Unknown Project"
        }
    }
    
    var daysUntilExpiry: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
    }
    
    var expiryDescription: String {
        if isExpired {
            return "Expired"
        } else if daysUntilExpiry == 0 {
            return "Expires today"
        } else if daysUntilExpiry == 1 {
            return "Expires tomorrow"
        } else {
            return "Expires in \(daysUntilExpiry) days"
        }
    }
}

// MARK: - Invitation Actions
extension Invitation {
    func accept() {
        guard canAccept else { return }
        status = "accepted"
        acceptedAt = Date()
    }
    
    func decline() {
        guard isPending else { return }
        status = "declined"
        declinedAt = Date()
    }
    
    func cancel() {
        guard isPending else { return }
        status = "cancelled"
    }
    
    func resend() {
        guard status != "accepted" else { return }
        token = UUID().uuidString
        expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        status = "pending"
    }
}

// MARK: - Invitation Deep Link
extension Invitation {
    var deepLinkURL: URL? {
        URL(string: "taskflow://invite/\(token)")
    }
    
    var webAcceptURL: URL? {
        URL(string: "https://taskflow.dev/invite/\(token)")
    }
    
    static func parseToken(from url: URL) -> String? {
        // Parse taskflow://invite/{token}
        guard url.scheme == "taskflow",
              url.host == "invite" else {
            return nil
        }
        return url.lastPathComponent
    }
}

// MARK: - Invitation Stats
extension Invitation {
    struct InvitationStats {
        let total: Int
        let pending: Int
        let accepted: Int
        let declined: Int
        let expired: Int
        
        var pendingPercentage: Double {
            guard total > 0 else { return 0 }
            return Double(pending) / Double(total) * 100
        }
        
        var acceptedPercentage: Double {
            guard total > 0 else { return 0 }
            return Double(accepted) / Double(total) * 100
        }
    }
    
    static func getStats(for invitations: [Invitation]) -> InvitationStats {
        InvitationStats(
            total: invitations.count,
            pending: invitations.filter { $0.isPending }.count,
            accepted: invitations.filter { $0.status == "accepted" }.count,
            declined: invitations.filter { $0.status == "declined" }.count,
            expired: invitations.filter { $0.isExpired }.count
        )
    }
}
