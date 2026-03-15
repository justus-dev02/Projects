//
//  WorkspaceUserModelTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for Workspace and User Models
//

import XCTest
@testable import Projects

@MainActor
final class WorkspaceUserModelTests: XCTestCase {
    
    // MARK: - Workspace Initialization Tests
    
    func testWorkspace_Initialization_WithDefaultValues() {
        // Given & When
        let workspace = Workspace(name: "Test Workspace")
        
        // Then
        XCTAssertEqual(workspace.name, "Test Workspace")
        XCTAssertNil(workspace.workspaceDescription)
        XCTAssertEqual(workspace.color, "#2D5BFF")
        XCTAssertEqual(workspace.icon, "briefcase.fill")
        XCTAssertFalse(workspace.isArchived)
        XCTAssertNotNil(workspace.id)
        XCTAssertNotNil(workspace.createdAt)
        XCTAssertNotNil(workspace.updatedAt)
    }
    
    func testWorkspace_Initialization_WithCustomValues() {
        // Given
        let name = "Custom Workspace"
        let description = "Workspace description"
        let color = "#FF6B6B"
        let icon = "star.fill"
        let isArchived = true
        
        // When
        let workspace = Workspace(
            name: name,
            workspaceDescription: description,
            color: color,
            icon: icon,
            isArchived: isArchived
        )
        
        // Then
        XCTAssertEqual(workspace.name, name)
        XCTAssertEqual(workspace.workspaceDescription, description)
        XCTAssertEqual(workspace.color, color)
        XCTAssertEqual(workspace.icon, icon)
        XCTAssertTrue(workspace.isArchived)
    }
    
    func testWorkspace_UniqueID() {
        // Given & When
        let workspace1 = Workspace(name: "Workspace 1")
        let workspace2 = Workspace(name: "Workspace 2")
        
        // Then
        XCTAssertNotEqual(workspace1.id, workspace2.id)
    }
    
    // MARK: - Workspace Computed Properties Tests
    
    func testWorkspace_ProjectCount_WhenNoProjects() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        
        // Then
        XCTAssertEqual(workspace.projectCount, 0)
    }
    
    func testWorkspace_ProjectCount_WhenProjectsExist() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        let project3 = Project(name: "Project 3")
        workspace.projects = [project1, project2, project3]
        
        // Then
        XCTAssertEqual(workspace.projectCount, 3)
    }
    
    func testWorkspace_MemberCount_WhenNoMembers() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        
        // Then
        XCTAssertEqual(workspace.memberCount, 0)
    }
    
    func testWorkspace_MemberCount_WhenMembersExist() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let member1 = WorkspaceMember()
        member1.user = user1
        let member2 = WorkspaceMember()
        member2.user = user2
        workspace.members = [member1, member2]
        
        // Then
        XCTAssertEqual(workspace.memberCount, 2)
    }
    
    func testWorkspace_ActiveProjectCount() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project1 = Project(name: "Project 1")
        project1.status = "active"
        project1.isArchived = false
        let project2 = Project(name: "Project 2")
        project2.status = "active"
        project2.isArchived = false
        let project3 = Project(name: "Project 3")
        project3.status = "completed"
        project3.isArchived = false
        let project4 = Project(name: "Project 4")
        project4.status = "active"
        project4.isArchived = true
        workspace.projects = [project1, project2, project3, project4]
        
        // Then
        XCTAssertEqual(workspace.activeProjectCount, 2)
    }
    
    func testWorkspace_CompletedProjectCount() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project1 = Project(name: "Project 1")
        project1.status = "completed"
        let project2 = Project(name: "Project 2")
        project2.status = "active"
        let project3 = Project(name: "Project 3")
        project3.status = "completed"
        workspace.projects = [project1, project2, project3]
        
        // Then
        XCTAssertEqual(workspace.completedProjectCount, 2)
    }
    
    // MARK: - Workspace Relationship Tests
    
    func testWorkspace_OwnerRelationship() {
        // Given
        let owner = User(email: "owner@example.com", displayName: "Owner", role: "owner")
        let workspace = Workspace(name: "Test Workspace")
        
        // When
        workspace.owner = owner
        
        // Then
        XCTAssertEqual(workspace.owner, owner)
    }
    
    func testWorkspace_ProjectsRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")
        
        // When
        workspace.projects = [project1, project2]
        
        // Then
        XCTAssertEqual(workspace.projects?.count, 2)
    }
    
    func testWorkspace_MembersRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let member1 = WorkspaceMember(role: "member")
        member1.user = user1
        let member2 = WorkspaceMember(role: "admin")
        member2.user = user2
        
        // When
        workspace.members = [member1, member2]
        
        // Then
        XCTAssertEqual(workspace.members?.count, 2)
    }
    
    func testWorkspace_LabelsRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let label1 = Label(name: "Bug", color: "#FF4757")
        let label2 = Label(name: "Feature", color: "#2D5BFF")
        
        // When
        workspace.labels = [label1, label2]
        
        // Then
        XCTAssertEqual(workspace.labels?.count, 2)
    }
    
    func testWorkspace_InvitationsRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let invitation1 = Invitation(email: "user1@example.com", inviteType: "workspace")
        let invitation2 = Invitation(email: "user2@example.com", inviteType: "workspace")
        
        // When
        workspace.invitations = [invitation1, invitation2]
        
        // Then
        XCTAssertEqual(workspace.invitations?.count, 2)
    }
    
    func testWorkspace_TemplatesRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let template1 = TaskTemplate(name: "Template 1", category: "general")
        let template2 = TaskTemplate(name: "Template 2", category: "bug")
        
        // When
        workspace.templates = [template1, template2]
        
        // Then
        XCTAssertEqual(workspace.templates?.count, 2)
    }
    
    // MARK: - WorkspaceMember Tests
    
    func testWorkspaceMember_Initialization_WithDefaultValues() {
        // Given & When
        let member = WorkspaceMember()
        
        // Then
        XCTAssertNotNil(member.id)
        XCTAssertEqual(member.role, "member")
        XCTAssertNotNil(member.joinedAt)
    }
    
    func testWorkspaceMember_Initialization_WithCustomValues() {
        // Given
        let role = "owner"
        let joinedAt = Date().addingTimeInterval(-3600)
        
        // When
        let member = WorkspaceMember(role: role, joinedAt: joinedAt)
        
        // Then
        XCTAssertEqual(member.role, role)
        XCTAssertEqual(member.joinedAt, joinedAt)
    }
    
    func testWorkspaceMember_UserRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let member = WorkspaceMember()
        
        // When
        member.user = user
        
        // Then
        XCTAssertEqual(member.user, user)
    }
    
    func testWorkspaceMember_WorkspaceRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let member = WorkspaceMember()
        
        // When
        member.workspace = workspace
        
        // Then
        XCTAssertEqual(member.workspace, workspace)
    }
    
    // MARK: - User Initialization Tests
    
    func testUser_Initialization_WithDefaultValues() {
        // Given & When
        let user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        
        // Then
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.role, "member")
        XCTAssertTrue(user.isLocalUser)
        XCTAssertNotNil(user.id)
        XCTAssertNotNil(user.createdAt)
        XCTAssertNil(user.lastActiveAt)
        // Avatar color should be randomly generated
        XCTAssertNotNil(user.avatarColor)
    }
    
    func testUser_Initialization_WithCustomValues() {
        // Given
        let email = "custom@example.com"
        let displayName = "Custom User"
        let avatarColor = "#FF6B6B"
        let role = "admin"
        let isLocalUser = false
        let createdAt = Date().addingTimeInterval(-3600)
        let lastActiveAt = Date()
        
        // When
        let user = User(
            email: email,
            displayName: displayName,
            avatarColor: avatarColor,
            role: role,
            isLocalUser: isLocalUser,
            createdAt: createdAt,
            lastActiveAt: lastActiveAt
        )
        
        // Then
        XCTAssertEqual(user.email, email)
        XCTAssertEqual(user.displayName, displayName)
        XCTAssertEqual(user.avatarColor, avatarColor)
        XCTAssertEqual(user.role, role)
        XCTAssertFalse(user.isLocalUser)
        XCTAssertEqual(user.createdAt, createdAt)
        XCTAssertEqual(user.lastActiveAt, lastActiveAt)
    }
    
    func testUser_UniqueID() {
        // Given & When
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        
        // Then
        XCTAssertNotEqual(user1.id, user2.id)
    }
    
    func testUser_GenerateRandomColor() {
        // Given
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"]
        
        // When
        let color = User.generateRandomColor()
        
        // Then
        XCTAssertTrue(colors.contains(color))
    }
    
    func testUser_GenerateRandomColor_MultipleTimes() {
        // Given & When
        let color1 = User.generateRandomColor()
        let color2 = User.generateRandomColor()
        let color3 = User.generateRandomColor()
        
        // Then - Colors should be valid hex colors
        XCTAssertTrue(color1.hasPrefix("#"))
        XCTAssertTrue(color2.hasPrefix("#"))
        XCTAssertTrue(color3.hasPrefix("#"))
    }
    
    // MARK: - User Role Extension Tests
    
    func testUserRoleEnum_AllCases() {
        // Then
        XCTAssertEqual(User.Role.allCases.count, 5)
        XCTAssertEqual(User.Role.owner, .owner)
        XCTAssertEqual(User.Role.admin, .admin)
        XCTAssertEqual(User.Role.member, .member)
        XCTAssertEqual(User.Role.guest, .guest)
        XCTAssertEqual(User.Role.viewer, .viewer)
    }
    
    func testUserRole_RawValues() {
        // Then
        XCTAssertEqual(User.Role.owner.rawValue, "Owner")
        XCTAssertEqual(User.Role.admin.rawValue, "Admin")
        XCTAssertEqual(User.Role.member.rawValue, "Member")
        XCTAssertEqual(User.Role.guest.rawValue, "Guest")
        XCTAssertEqual(User.Role.viewer.rawValue, "Viewer")
    }
    
    func testUserRole_Icons() {
        // Then
        XCTAssertEqual(User.Role.owner.icon, "crown.fill")
        XCTAssertEqual(User.Role.admin.icon, "star.fill")
        XCTAssertEqual(User.Role.member.icon, "person.fill")
        XCTAssertEqual(User.Role.guest.icon, "person.badge.plus")
        XCTAssertEqual(User.Role.viewer.icon, "eye.fill")
    }
    
    func testUserRole_CanEdit() {
        // Then
        XCTAssertTrue(User.Role.owner.canEdit)
        XCTAssertTrue(User.Role.admin.canEdit)
        XCTAssertTrue(User.Role.member.canEdit)
        XCTAssertFalse(User.Role.guest.canEdit)
        XCTAssertFalse(User.Role.viewer.canEdit)
    }
    
    func testUserRole_CanDelete() {
        // Then
        XCTAssertTrue(User.Role.owner.canDelete)
        XCTAssertTrue(User.Role.admin.canDelete)
        XCTAssertFalse(User.Role.member.canDelete)
        XCTAssertFalse(User.Role.guest.canDelete)
        XCTAssertFalse(User.Role.viewer.canDelete)
    }
    
    func testUserRole_CanInvite() {
        // Then
        XCTAssertTrue(User.Role.owner.canInvite)
        XCTAssertTrue(User.Role.admin.canInvite)
        XCTAssertFalse(User.Role.member.canInvite)
        XCTAssertFalse(User.Role.guest.canInvite)
        XCTAssertFalse(User.Role.viewer.canInvite)
    }
    
    // MARK: - User Relationship Tests
    
    func testUser_WorkspacesRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let workspace1 = Workspace(name: "Workspace 1")
        let workspace2 = Workspace(name: "Workspace 2")
        
        // When
        user.workspaces = [workspace1, workspace2]
        
        // Then
        XCTAssertEqual(user.workspaces?.count, 2)
    }
    
    func testUser_OwnedWorkspacesRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let workspace1 = Workspace(name: "Workspace 1")
        let workspace2 = Workspace(name: "Workspace 2")
        
        // When
        user.ownedWorkspaces = [workspace1, workspace2]
        
        // Then
        XCTAssertEqual(user.ownedWorkspaces?.count, 2)
    }
    
    func testUser_TasksRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let task1 = Task(title: "Task 1")
        let task2 = Task(title: "Task 2")
        
        // When
        user.tasks = [task1, task2]
        
        // Then
        XCTAssertEqual(user.tasks?.count, 2)
    }
    
    func testUser_CommentsRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let comment1 = Comment(content: "Comment 1")
        let comment2 = Comment(content: "Comment 2")
        
        // When
        user.comments = [comment1, comment2]
        
        // Then
        XCTAssertEqual(user.comments?.count, 2)
    }
    
    func testUser_NotificationsRelationship() {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let notification1 = NotificationModel(title: "Notification 1", message: "Message 1")
        let notification2 = NotificationModel(title: "Notification 2", message: "Message 2")
        
        // When
        user.notifications = [notification1, notification2]
        
        // Then
        XCTAssertEqual(user.notifications?.count, 2)
    }
}
