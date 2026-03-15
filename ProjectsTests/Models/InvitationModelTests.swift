//
//  InvitationModelTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for Invitation Model
//

import XCTest
@testable import Projects

@MainActor
final class InvitationModelTests: XCTestCase {
    
    // MARK: - Invitation Initialization Tests
    
    func testInvitation_Initialization_WithDefaultValues() {
        // Given & When
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace"
        )
        
        // Then
        XCTAssertEqual(invitation.email, "test@example.com")
        XCTAssertEqual(invitation.inviteType, "workspace")
        XCTAssertEqual(invitation.role, "member")
        XCTAssertEqual(invitation.status, "pending")
        XCTAssertNotNil(invitation.token)
        XCTAssertNil(invitation.message)
        XCTAssertNotNil(invitation.expiresAt)
        XCTAssertNotNil(invitation.createdAt)
        XCTAssertNil(invitation.acceptedAt)
        XCTAssertNil(invitation.declinedAt)
        XCTAssertNotNil(invitation.id)
    }
    
    func testInvitation_Initialization_WithCustomValues() {
        // Given
        let email = "custom@example.com"
        let inviteType = "project"
        let role = "admin"
        let status = "accepted"
        let token = "custom-token-123"
        let message = "Join our team!"
        let expiresAt = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let createdAt = Date().addingTimeInterval(-3600)
        let acceptedAt = Date()
        
        // When
        let invitation = Invitation(
            email: email,
            inviteType: inviteType,
            role: role,
            status: status,
            token: token,
            message: message,
            expiresAt: expiresAt,
            createdAt: createdAt,
            acceptedAt: acceptedAt
        )
        
        // Then
        XCTAssertEqual(invitation.email, email)
        XCTAssertEqual(invitation.inviteType, inviteType)
        XCTAssertEqual(invitation.role, role)
        XCTAssertEqual(invitation.status, status)
        XCTAssertEqual(invitation.token, token)
        XCTAssertEqual(invitation.message, message)
        XCTAssertEqual(invitation.expiresAt, expiresAt)
        XCTAssertEqual(invitation.createdAt, createdAt)
        XCTAssertEqual(invitation.acceptedAt, acceptedAt)
    }
    
    func testInvitation_UniqueID() {
        // Given & When
        let invitation1 = Invitation(email: "test1@example.com", inviteType: "workspace")
        let invitation2 = Invitation(email: "test2@example.com", inviteType: "project")
        
        // Then
        XCTAssertNotEqual(invitation1.id, invitation2.id)
    }
    
    func testInvitation_GeneratesToken_WhenEmpty() {
        // Given & When
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            token: ""
        )
        
        // Then
        XCTAssertNotNil(invitation.token)
        XCTAssertFalse(invitation.token.isEmpty)
    }
    
    func testInvitation_UsesProvidedToken() {
        // Given
        let customToken = "my-custom-token"
        
        // When
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            token: customToken
        )
        
        // Then
        XCTAssertEqual(invitation.token, customToken)
    }
    
    // MARK: - Invitation Status Extension Tests
    
    func testInvitationStatusEnum_AllCases() {
        // Then
        XCTAssertEqual(Invitation.Status.allCases.count, 5)
        XCTAssertEqual(Invitation.Status.pending, .pending)
        XCTAssertEqual(Invitation.Status.accepted, .accepted)
        XCTAssertEqual(Invitation.Status.declined, .declined)
        XCTAssertEqual(Invitation.Status.expired, .expired)
        XCTAssertEqual(Invitation.Status.cancelled, .cancelled)
    }
    
    func testInvitationStatus_RawValues() {
        // Then
        XCTAssertEqual(Invitation.Status.pending.rawValue, "Pending")
        XCTAssertEqual(Invitation.Status.accepted.rawValue, "Accepted")
        XCTAssertEqual(Invitation.Status.declined.rawValue, "Declined")
        XCTAssertEqual(Invitation.Status.expired.rawValue, "Expired")
        XCTAssertEqual(Invitation.Status.cancelled.rawValue, "Cancelled")
    }
    
    func testInvitationStatus_Colors() {
        // Then
        XCTAssertEqual(Invitation.Status.pending.color, "#FFB020")
        XCTAssertEqual(Invitation.Status.accepted.color, "#00BA88")
        XCTAssertEqual(Invitation.Status.declined.color, "#FF4757")
        XCTAssertEqual(Invitation.Status.expired.color, "#95A5A6")
        XCTAssertEqual(Invitation.Status.cancelled.color, "#95A5A6")
    }
    
    func testInvitationStatus_Icons() {
        // Then
        XCTAssertEqual(Invitation.Status.pending.icon, "clock.fill")
        XCTAssertEqual(Invitation.Status.accepted.icon, "checkmark.circle.fill")
        XCTAssertEqual(Invitation.Status.declined.icon, "xmark.circle.fill")
        XCTAssertEqual(Invitation.Status.expired.icon, "exclamationmark.circle.fill")
        XCTAssertEqual(Invitation.Status.cancelled.icon, "slash.circle.fill")
    }
    
    // MARK: - Invite Type Extension Tests
    
    func testInvitationInviteTypeEnum_AllCases() {
        // Then
        XCTAssertEqual(Invitation.InviteType.allCases.count, 2)
        XCTAssertEqual(Invitation.InviteType.workspace, .workspace)
        XCTAssertEqual(Invitation.InviteType.project, .project)
    }
    
    func testInvitationInviteType_RawValues() {
        // Then
        XCTAssertEqual(Invitation.InviteType.workspace.rawValue, "Workspace")
        XCTAssertEqual(Invitation.InviteType.project.rawValue, "Project")
    }
    
    func testInvitationInviteType_Icons() {
        // Then
        XCTAssertEqual(Invitation.InviteType.workspace.icon, "briefcase.fill")
        XCTAssertEqual(Invitation.InviteType.project.icon, "folder.fill")
    }
    
    // MARK: - Invitation Computed Properties Tests
    
    func testInvitation_IsExpired_WhenPastExpiryDate() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: pastDate
        )
        
        // Then
        XCTAssertTrue(invitation.isExpired)
    }
    
    func testInvitation_IsExpired_WhenFutureExpiryDate() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: futureDate
        )
        
        // Then
        XCTAssertFalse(invitation.isExpired)
    }
    
    func testInvitation_IsExpired_WhenStatusNotPending() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "accepted",
            expiresAt: pastDate
        )
        
        // Then
        XCTAssertFalse(invitation.isExpired)
    }
    
    func testInvitation_IsPending_WhenStatusPendingAndNotExpired() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: futureDate
        )
        
        // Then
        XCTAssertTrue(invitation.isPending)
    }
    
    func testInvitation_IsPending_WhenStatusNotPending() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "accepted",
            expiresAt: futureDate
        )
        
        // Then
        XCTAssertFalse(invitation.isPending)
    }
    
    func testInvitation_IsPending_WhenExpired() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: pastDate
        )
        
        // Then
        XCTAssertFalse(invitation.isPending)
    }
    
    func testInvitation_CanAccept_WhenPending() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: futureDate
        )
        
        // Then
        XCTAssertTrue(invitation.canAccept)
    }
    
    func testInvitation_CanAccept_WhenNotPending() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "accepted"
        )
        
        // Then
        XCTAssertFalse(invitation.canAccept)
    }
    
    func testInvitation_CanAccept_WhenExpired() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: pastDate
        )
        
        // Then
        XCTAssertFalse(invitation.canAccept)
    }
    
    func testInvitation_InviteeDisplayName_WhenInviteeExists() {
        // Given
        let invitee = User(email: "invitee@example.com", displayName: "Invitee User")
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace"
        )
        invitation.invitee = invitee
        
        // Then
        XCTAssertEqual(invitation.inviteeDisplayName, "Invitee User")
    }
    
    func testInvitation_InviteeDisplayName_WhenNoInvitee() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace"
        )
        
        // Then
        XCTAssertEqual(invitation.inviteeDisplayName, "test@example.com")
    }
    
    func testInvitation_TargetName_WhenWorkspace() {
        // Given
        let workspace = Workspace(name: "Target Workspace")
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace"
        )
        invitation.workspace = workspace
        
        // Then
        XCTAssertEqual(invitation.targetName, "Target Workspace")
    }
    
    func testInvitation_TargetName_WhenProject() {
        // Given
        let project = Project(name: "Target Project")
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "project"
        )
        invitation.project = project
        
        // Then
        XCTAssertEqual(invitation.targetName, "Target Project")
    }
    
    func testInvitation_TargetName_WhenNoTarget() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace"
        )
        
        // Then
        XCTAssertEqual(invitation.targetName, "Unknown Workspace")
    }
    
    func testInvitation_DaysUntilExpiry() {
        // Given
        let fiveDaysFromNow = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            expiresAt: fiveDaysFromNow
        )
        
        // Then
        XCTAssertEqual(invitation.daysUntilExpiry, 5)
    }
    
    func testInvitation_ExpiryDescription_WhenExpired() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: pastDate
        )
        
        // Then
        XCTAssertEqual(invitation.expiryDescription, "Expired")
    }
    
    func testInvitation_ExpiryDescription_WhenExpiresToday() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            expiresAt: Date()
        )
        
        // Then
        XCTAssertEqual(invitation.expiryDescription, "Expires today")
    }
    
    func testInvitation_ExpiryDescription_WhenExpiresTomorrow() {
        // Given
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            expiresAt: tomorrow
        )
        
        // Then
        XCTAssertEqual(invitation.expiryDescription, "Expires tomorrow")
    }
    
    func testInvitation_ExpiryDescription_WhenExpiresInMultipleDays() {
        // Given
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            expiresAt: sevenDaysFromNow
        )
        
        // Then
        XCTAssertEqual(invitation.expiryDescription, "Expires in 7 days")
    }
    
    // MARK: - Invitation Actions Tests
    
    func testInvitation_Accept_WhenPending() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: futureDate
        )
        
        // When
        invitation.accept()
        
        // Then
        XCTAssertEqual(invitation.status, "accepted")
        XCTAssertNotNil(invitation.acceptedAt)
    }
    
    func testInvitation_Accept_WhenNotPending() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "declined"
        )
        let previousAcceptedAt = invitation.acceptedAt
        
        // When
        invitation.accept()
        
        // Then
        XCTAssertEqual(invitation.status, "declined")
        XCTAssertEqual(invitation.acceptedAt, previousAcceptedAt)
    }
    
    func testInvitation_Decline_WhenPending() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending"
        )
        
        // When
        invitation.decline()
        
        // Then
        XCTAssertEqual(invitation.status, "declined")
        XCTAssertNotNil(invitation.declinedAt)
    }
    
    func testInvitation_Decline_WhenNotPending() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "accepted"
        )
        
        // When
        invitation.decline()
        
        // Then
        XCTAssertEqual(invitation.status, "accepted")
    }
    
    func testInvitation_Cancel_WhenPending() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "pending"
        )
        
        // When
        invitation.cancel()
        
        // Then
        XCTAssertEqual(invitation.status, "cancelled")
    }
    
    func testInvitation_Cancel_WhenNotPending() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "accepted"
        )
        
        // When
        invitation.cancel()
        
        // Then
        XCTAssertEqual(invitation.status, "accepted")
    }
    
    func testInvitation_Resend_WhenNotAccepted() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "declined",
            token: "old-token"
        )
        let oldToken = invitation.token
        
        // When
        invitation.resend()
        
        // Then
        XCTAssertEqual(invitation.status, "pending")
        XCTAssertNotEqual(invitation.token, oldToken)
        XCTAssertGreaterThan(invitation.expiresAt, Date())
    }
    
    func testInvitation_Resend_WhenAccepted() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            status: "accepted"
        )
        let oldStatus = invitation.status
        let oldToken = invitation.token
        
        // When
        invitation.resend()
        
        // Then
        XCTAssertEqual(invitation.status, oldStatus)
        XCTAssertEqual(invitation.token, oldToken)
    }
    
    // MARK: - Invitation Deep Link Tests
    
    func testInvitation_DeepLinkURL() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            token: "test-token-123"
        )
        
        // Then
        XCTAssertEqual(invitation.deepLinkURL, URL(string: "taskflow://invite/test-token-123"))
    }
    
    func testInvitation_WebAcceptURL() {
        // Given
        let invitation = Invitation(
            email: "test@example.com",
            inviteType: "workspace",
            token: "test-token-123"
        )
        
        // Then
        XCTAssertEqual(invitation.webAcceptURL, URL(string: "https://taskflow.dev/invite/test-token-123"))
    }
    
    func testInvitation_ParseToken_FromValidURL() {
        // Given
        let url = URL(string: "taskflow://invite/test-token-123")!
        
        // When
        let token = Invitation.parseToken(from: url)
        
        // Then
        XCTAssertEqual(token, "test-token-123")
    }
    
    func testInvitation_ParseToken_FromInvalidScheme() {
        // Given
        let url = URL(string: "https://taskflow.dev/invite/test-token-123")!
        
        // When
        let token = Invitation.parseToken(from: url)
        
        // Then
        XCTAssertNil(token)
    }
    
    func testInvitation_ParseToken_FromInvalidHost() {
        // Given
        let url = URL(string: "taskflow://invalid/test-token-123")!
        
        // When
        let token = Invitation.parseToken(from: url)
        
        // Then
        XCTAssertNil(token)
    }
    
    // MARK: - Invitation Stats Tests
    
    func testInvitationStats_Initialization() {
        // Given
        let stats = Invitation.InvitationStats(
            total: 10,
            pending: 3,
            accepted: 5,
            declined: 1,
            expired: 1
        )
        
        // Then
        XCTAssertEqual(stats.total, 10)
        XCTAssertEqual(stats.pending, 3)
        XCTAssertEqual(stats.accepted, 5)
        XCTAssertEqual(stats.declined, 1)
        XCTAssertEqual(stats.expired, 1)
    }
    
    func testInvitationStats_PendingPercentage() {
        // Given
        let stats = Invitation.InvitationStats(
            total: 10,
            pending: 3,
            accepted: 5,
            declined: 1,
            expired: 1
        )
        
        // Then
        XCTAssertEqual(stats.pendingPercentage, 30.0)
    }
    
    func testInvitationStats_PendingPercentage_WhenZeroTotal() {
        // Given
        let stats = Invitation.InvitationStats(
            total: 0,
            pending: 0,
            accepted: 0,
            declined: 0,
            expired: 0
        )
        
        // Then
        XCTAssertEqual(stats.pendingPercentage, 0)
    }
    
    func testInvitationStats_AcceptedPercentage() {
        // Given
        let stats = Invitation.InvitationStats(
            total: 10,
            pending: 3,
            accepted: 5,
            declined: 1,
            expired: 1
        )
        
        // Then
        XCTAssertEqual(stats.acceptedPercentage, 50.0)
    }
    
    func testInvitationStats_AcceptedPercentage_WhenZeroTotal() {
        // Given
        let stats = Invitation.InvitationStats(
            total: 0,
            pending: 0,
            accepted: 0,
            declined: 0,
            expired: 0
        )
        
        // Then
        XCTAssertEqual(stats.acceptedPercentage, 0)
    }
    
    func testInvitation_GetStats() {
        // Given
        let pending = Invitation(email: "pending@example.com", inviteType: "workspace", status: "pending")
        let accepted = Invitation(email: "accepted@example.com", inviteType: "workspace", status: "accepted")
        let declined = Invitation(email: "declined@example.com", inviteType: "workspace", status: "declined")
        let expired = Invitation(
            email: "expired@example.com",
            inviteType: "workspace",
            status: "pending",
            expiresAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        )
        
        let invitations = [pending, accepted, declined, expired]
        
        // When
        let stats = Invitation.getStats(for: invitations)
        
        // Then
        XCTAssertEqual(stats.total, 4)
        XCTAssertEqual(stats.pending, 1)
        XCTAssertEqual(stats.accepted, 1)
        XCTAssertEqual(stats.declined, 1)
        XCTAssertEqual(stats.expired, 1)
    }
    
    func testInvitation_GetStats_WhenEmpty() {
        // Given
        let invitations: [Invitation] = []
        
        // When
        let stats = Invitation.getStats(for: invitations)
        
        // Then
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.pending, 0)
        XCTAssertEqual(stats.accepted, 0)
        XCTAssertEqual(stats.declined, 0)
        XCTAssertEqual(stats.expired, 0)
    }
    
    // MARK: - Invitation Relationship Tests
    
    func testInvitation_InviterRelationship() {
        // Given
        let inviter = User(email: "inviter@example.com", displayName: "Inviter")
        let invitation = Invitation(email: "test@example.com", inviteType: "workspace")
        
        // When
        invitation.inviter = inviter
        
        // Then
        XCTAssertEqual(invitation.inviter, inviter)
    }
    
    func testInvitation_WorkspaceRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let invitation = Invitation(email: "test@example.com", inviteType: "workspace")
        
        // When
        invitation.workspace = workspace
        
        // Then
        XCTAssertEqual(invitation.workspace, workspace)
    }
    
    func testInvitation_ProjectRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let invitation = Invitation(email: "test@example.com", inviteType: "project")
        
        // When
        invitation.project = project
        
        // Then
        XCTAssertEqual(invitation.project, project)
    }
    
    func testInvitation_InviteeRelationship() {
        // Given
        let invitee = User(email: "invitee@example.com", displayName: "Invitee")
        let invitation = Invitation(email: "test@example.com", inviteType: "workspace")
        
        // When
        invitation.invitee = invitee
        
        // Then
        XCTAssertEqual(invitation.invitee, invitee)
    }
}
