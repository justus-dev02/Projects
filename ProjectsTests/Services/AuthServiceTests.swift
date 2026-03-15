//
//  AuthServiceTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for AuthService
//

import XCTest
@testable import Projects
import SwiftData
import Combine

@MainActor
final class AuthServiceTests: XCTestCase {
    
    var authService: AuthService!
    var dataService: DataService!
    var modelContext: ModelContext!
    var testUserDefaults: UserDefaults!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            User.self,
            Workspace.self,
            WorkspaceMember.self,
            Project.self,
            ProjectMember.self,
            BoardColumn.self,
            Task.self,
            Subtask.self,
            Comment.self,
            Attachment.self,
            TaskLabel.self,
            TaskCollaborator.self,
            ActivityLog.self,
            Label.self,
            NotificationModel.self,
            SavedView.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = container.mainContext
        dataService = DataService(modelContext: modelContext)
        
        // Create test UserDefaults
        testUserDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        
        // Create auth service with test data
        authService = AuthService(modelContext: modelContext, userDefaults: testUserDefaults)
    }
    
    override func tearDown() async throws {
        if let suiteName = testUserDefaults?.suiteName {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        authService = nil
        dataService = nil
        modelContext = nil
        testUserDefaults = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAuthService_InitialState() {
        // Then
        XCTAssertNil(authService.currentUser)
        XCTAssertEqual(authService.authState, .unknown)
    }
    
    // MARK: - Local Login Tests
    
    func testLoginLocally_CreatesLocalUser() throws {
        // When
        let user = try authService.loginLocally()
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.email, "local@taskflow.dev")
        XCTAssertEqual(user.displayName, "Local User")
        XCTAssertTrue(user.isLocalUser)
        XCTAssertEqual(authService.authState, .authenticated(user))
    }
    
    func testLoginLocally_UsesExistingLocalUser() throws {
        // Given - Create local user first
        let existingUser = User(
            email: "local@taskflow.dev",
            displayName: "Existing Local User",
            isLocalUser: true
        )
        dataService.insert(existingUser)
        try dataService.save()
        
        // When
        let user = try authService.loginLocally()
        
        // Then
        XCTAssertEqual(user.id, existingUser.id)
        XCTAssertEqual(user.displayName, "Existing Local User")
    }
    
    func testLoginLocally_UpdatesAuthState() throws {
        // When
        _ = try authService.loginLocally()
        
        // Then
        XCTAssertNotNil(authService.currentUser)
        XCTAssertEqual(authService.authState, .authenticated(authService.currentUser!))
    }
    
    // MARK: - Register Tests
    
    func testRegister_Success() async throws {
        // When
        let user = try await authService.register(
            email: "newuser@example.com",
            password: "SecurePass123",
            displayName: "New User"
        )
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user.email, "newuser@example.com")
        XCTAssertEqual(user.displayName, "New User")
        XCTAssertFalse(user.isLocalUser)
        XCTAssertEqual(authService.currentUser, user)
        XCTAssertEqual(authService.authState, .authenticated(user))
    }
    
    func testRegister_SavesSession() async throws {
        // When
        let user = try await authService.register(
            email: "newuser@example.com",
            password: "SecurePass123",
            displayName: "New User"
        )
        
        // Then
        let storedUserId = testUserDefaults.string(forKey: "currentUserId")
        XCTAssertEqual(storedUserId, user.id)
    }
    
    func testRegister_InvalidEmail() async {
        // When/Then
        do {
            _ = try await authService.register(
                email: "",
                password: "SecurePass123",
                displayName: "New User"
            )
            XCTFail("Should have thrown error")
        } catch AuthError.invalidEmail {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testRegister_WeakPassword() async {
        // When/Then
        do {
            _ = try await authService.register(
                email: "test@example.com",
                password: "weak",
                displayName: "New User"
            )
            XCTFail("Should have thrown error")
        } catch AuthError.weakPassword {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testRegister_InvalidDisplayName() async {
        // When/Then
        do {
            _ = try await authService.register(
                email: "test@example.com",
                password: "SecurePass123",
                displayName: ""
            )
            XCTFail("Should have thrown error")
        } catch AuthError.invalidDisplayName {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testRegister_UserAlreadyExists() async throws {
        // Given
        let existingUser = User(
            email: "existing@example.com",
            displayName: "Existing User"
        )
        dataService.insert(existingUser)
        try dataService.save()
        
        // When/Then
        do {
            _ = try await authService.register(
                email: "existing@example.com",
                password: "SecurePass123",
                displayName: "New User"
            )
            XCTFail("Should have thrown error")
        } catch AuthError.userAlreadyExists {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - Login Tests
    
    func testLogin_DemoUser_Success() async throws {
        // Given
        let demoUser = User(
            email: "demo@taskflow.dev",
            displayName: "Demo User"
        )
        dataService.insert(demoUser)
        try dataService.save()
        
        // When
        let user = try await authService.login(
            email: "demo@taskflow.dev",
            password: "any"
        )
        
        // Then
        XCTAssertEqual(user.email, "demo@taskflow.dev")
        XCTAssertEqual(authService.currentUser, user)
    }
    
    func testLogin_ValidCredentials_Success() async throws {
        // Given
        let user = User(
            email: "test@example.com",
            displayName: "Test User"
        )
        dataService.insert(user)
        try dataService.save()
        
        // When
        let loggedInUser = try await authService.login(
            email: "test@example.com",
            password: "Demo123!"
        )
        
        // Then
        XCTAssertEqual(loggedInUser.id, user.id)
        XCTAssertNotNil(user.lastActiveAt)
    }
    
    func testLogin_InvalidEmail() async {
        // When/Then
        do {
            _ = try await authService.login(
                email: "",
                password: "password"
            )
            XCTFail("Should have thrown error")
        } catch AuthError.invalidEmail {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testLogin_InvalidPassword() async {
        // When/Then
        do {
            _ = try await authService.login(
                email: "test@example.com",
                password: ""
            )
            XCTFail("Should have thrown error")
        } catch AuthError.invalidPassword {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testLogin_UserNotFound() async throws {
        // When/Then
        do {
            _ = try await authService.login(
                email: "nonexistent@example.com",
                password: "password"
            )
            XCTFail("Should have thrown error")
        } catch AuthError.userNotFound {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    func testLogin_InvalidCredentials() async throws {
        // Given - Create user that's not demo
        let user = User(
            email: "regular@example.com",
            displayName: "Regular User"
        )
        dataService.insert(user)
        try dataService.save()
        
        // When/Then
        do {
            _ = try await authService.login(
                email: "regular@example.com",
                password: "wrongpassword"
            )
            XCTFail("Should have thrown error")
        } catch AuthError.invalidCredentials {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - Logout Tests
    
    func testLogout_ClearsState() throws {
        // Given
        _ = try authService.loginLocally()
        XCTAssertNotNil(authService.currentUser)
        
        // When
        try authService.logout()
        
        // Then
        XCTAssertNil(authService.currentUser)
        XCTAssertEqual(authService.authState, .unauthenticated)
        XCTAssertNil(testUserDefaults.string(forKey: "currentUserId"))
    }
    
    func testLogout_PublishesState() throws {
        // Given
        _ = try authService.loginLocally()
        
        // When
        var receivedStates: [AuthState] = []
        let cancellable = authService.authStatePublisher.sink { state in
            receivedStates.append(state)
        }
        
        try authService.logout()
        
        // Then
        XCTAssertTrue(receivedStates.contains(.unauthenticated))
        _ = cancellable
    }
    
    // MARK: - Delete Account Tests
    
    func testDeleteAccount_Success() throws {
        // Given
        let user = try authService.loginLocally()
        
        // When
        try authService.deleteAccount()
        
        // Then
        XCTAssertNil(authService.currentUser)
        XCTAssertEqual(authService.authState, .unauthenticated)
        
        // Verify user is deleted from database
        let predicate = #Predicate<User> { $0.id == user.id }
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        XCTAssertNil(fetched)
    }
    
    func testDeleteAccount_WhenNotAuthenticated() {
        // When/Then
        do {
            try authService.deleteAccount()
            XCTFail("Should have thrown error")
        } catch AuthError.notAuthenticated {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - Update Profile Tests
    
    func testUpdateProfile_DisplayName() throws {
        // Given
        let user = try authService.loginLocally()
        
        // When
        try authService.updateProfile(displayName: "Updated Name")
        
        // Then
        XCTAssertEqual(authService.currentUser?.displayName, "Updated Name")
        XCTAssertEqual(user.displayName, "Updated Name")
    }
    
    func testUpdateProfile_AvatarColor() throws {
        // Given
        let user = try authService.loginLocally()
        let newColor = "#FF6B6B"
        
        // When
        try authService.updateProfile(avatarColor: newColor)
        
        // Then
        XCTAssertEqual(authService.currentUser?.avatarColor, newColor)
        XCTAssertEqual(user.avatarColor, newColor)
    }
    
    func testUpdateProfile_BothFields() throws {
        // Given
        let user = try authService.loginLocally()
        let newName = "Updated Name"
        let newColor = "#FF6B6B"
        
        // When
        try authService.updateProfile(displayName: newName, avatarColor: newColor)
        
        // Then
        XCTAssertEqual(authService.currentUser?.displayName, newName)
        XCTAssertEqual(authService.currentUser?.avatarColor, newColor)
    }
    
    func testUpdateProfile_WhenNotAuthenticated() {
        // When/Then
        do {
            try authService.updateProfile(displayName: "New Name")
            XCTFail("Should have thrown error")
        } catch AuthError.notAuthenticated {
            // Expected
        } catch {
            XCTFail("Wrong error type")
        }
    }
    
    // MARK: - AuthState Tests
    
    func testAuthState_Equatable_Unknown() {
        // Then
        XCTAssertEqual(AuthState.unknown, AuthState.unknown)
    }
    
    func testAuthState_Equatable_Unauthenticated() {
        // Then
        XCTAssertEqual(AuthState.unauthenticated, AuthState.unauthenticated)
    }
    
    func testAuthState_Equatable_Authenticated_SameUser() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        let state1 = AuthState.authenticated(user)
        let state2 = AuthState.authenticated(user)
        
        // Then
        XCTAssertEqual(state1, state2)
    }
    
    func testAuthState_Equatable_Authenticated_DifferentUser() {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let state1 = AuthState.authenticated(user1)
        let state2 = AuthState.authenticated(user2)
        
        // Then
        XCTAssertNotEqual(state1, state2)
    }
    
    func testAuthState_Equatable_DifferentStates() {
        // Then
        XCTAssertNotEqual(AuthState.unknown, AuthState.unauthenticated)
        XCTAssertNotEqual(AuthState.unknown, AuthState.authenticated(User(email: "test@example.com", displayName: "Test")))
        XCTAssertNotEqual(AuthState.unauthenticated, AuthState.authenticated(User(email: "test@example.com", displayName: "Test")))
    }
    
    // MARK: - UserRepository Tests
    
    func testUserRepository_GetCurrentUser() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        dataService.insert(user)
        try dataService.save()
        testUserDefaults.set(user.id, forKey: "currentUserId")
        
        let repo = UserRepository(dataService: dataService)
        
        // When
        let currentUser = try repo.getCurrentUser()
        
        // Then
        XCTAssertEqual(currentUser?.id, user.id)
    }
    
    func testUserRepository_GetCurrentUser_NoStoredId() throws {
        // Given
        let repo = UserRepository(dataService: dataService)
        
        // When
        let currentUser = try repo.getCurrentUser()
        
        // Then
        XCTAssertNil(currentUser)
    }
    
    func testUserRepository_GetUserByEmail() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        dataService.insert(user)
        try dataService.save()
        
        let repo = UserRepository(dataService: dataService)
        
        // When
        let fetched = try repo.getUserByEmail("test@example.com")
        
        // Then
        XCTAssertEqual(fetched?.id, user.id)
    }
    
    func testUserRepository_GetUserByEmail_NotFound() throws {
        // Given
        let repo = UserRepository(dataService: dataService)
        
        // When
        let fetched = try repo.getUserByEmail("nonexistent@example.com")
        
        // Then
        XCTAssertNil(fetched)
    }
    
    func testUserRepository_GetAllUsers() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let user3 = User(email: "user3@example.com", displayName: "User 3")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        try dataService.save()
        
        let repo = UserRepository(dataService: dataService)
        
        // When
        let users = try repo.getAllUsers()
        
        // Then
        XCTAssertEqual(users.count, 3)
    }
    
    func testUserRepository_SearchUsers() throws {
        // Given
        let user1 = User(email: "john@example.com", displayName: "John Doe")
        let user2 = User(email: "jane@example.com", displayName: "Jane Smith")
        let user3 = User(email: "bob@example.com", displayName: "Bob Johnson")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        try dataService.save()
        
        let repo = UserRepository(dataService: dataService)
        
        // When
        let users = try repo.searchUsers(query: "john")
        
        // Then
        XCTAssertEqual(users.count, 2) // John Doe and Bob Johnson
    }
    
    func testUserRepository_SearchUsers_NoResults() throws {
        // Given
        let user1 = User(email: "john@example.com", displayName: "John Doe")
        dataService.insert(user1)
        try dataService.save()
        
        let repo = UserRepository(dataService: dataService)
        
        // When
        let users = try repo.searchUsers(query: "nonexistent")
        
        // Then
        XCTAssertEqual(users.count, 0)
    }
    
    // MARK: - AuthError Tests
    
    func testAuthError_ErrorDescriptions() {
        // Then
        XCTAssertEqual(AuthError.invalidEmail.errorDescription, "Bitte geben Sie eine gültige E-Mail-Adresse ein.")
        XCTAssertEqual(AuthError.invalidPassword.errorDescription, "Bitte geben Sie ein Passwort ein.")
        XCTAssertEqual(AuthError.invalidCredentials.errorDescription, "E-Mail oder Passwort ist falsch.")
        XCTAssertEqual(AuthError.weakPassword.errorDescription, "Das Passwort muss mindestens 8 Zeichen lang sein.")
        XCTAssertEqual(AuthError.invalidDisplayName.errorDescription, "Bitte geben Sie einen Anzeigenamen ein.")
        XCTAssertEqual(AuthError.userNotFound.errorDescription, "Benutzer nicht gefunden.")
        XCTAssertEqual(AuthError.userAlreadyExists.errorDescription, "Ein Benutzer mit dieser E-Mail existiert bereits.")
        XCTAssertEqual(AuthError.notAuthenticated.errorDescription, "Nicht authentifiziert.")
    }
}
