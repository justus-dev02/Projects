//
//  AuthService.swift
//  Projects
//
//  TaskFlow - Authentication Service
//

import Foundation
import SwiftData
import Combine

// MARK: - Auth State
enum AuthState: Equatable {
    case unknown
    case authenticated(User)
    case unauthenticated
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        default:
            return false
        }
    }
}

// MARK: - Auth Service Protocol
protocol AuthServiceProtocol {
    var currentUser: User? { get }
    var authState: AuthState { get }
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    
    func login(email: String, password: String) async throws -> User
    func register(email: String, password: String, displayName: String) async throws -> User
    func logout() throws
    func loginLocally() throws -> User
    func deleteAccount() throws
}

// MARK: - Auth Service Implementation
@MainActor
final class AuthService: AuthServiceProtocol, ObservableObject {
    static let shared = AuthService()

    private var dataService: DataService
    private let userDefaults: UserDefaults

    @Published private(set) var currentUser: User?
    @Published private(set) var authState: AuthState = .unknown

    private let authStateSubject = PassthroughSubject<AuthState, Never>()
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }

    private var userRepo: UserRepository

    init(
        dataService: DataService? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        // Use provided dataService or create one that will use the environment's ModelContext
        self.dataService = dataService ?? DataService()
        self.userDefaults = userDefaults
        self.userRepo = UserRepository(dataService: self.dataService)

        // Don't check session during init - wait for explicit call
        // This prevents database access before ModelContainer is ready
        currentUser = nil
        authState = .unknown
    }

    /// Initialize with a specific ModelContext from the environment
    init(modelContext: ModelContext?, userDefaults: UserDefaults = .standard) {
        if let context = modelContext {
            self.dataService = DataService(modelContext: context)
        } else {
            self.dataService = DataService()
        }
        self.userDefaults = userDefaults
        self.userRepo = UserRepository(dataService: self.dataService)

        currentUser = nil
        authState = .unknown
    }

    /// Call this after ModelContainer is ready
    func initializeAuthState() {
        checkExistingSession()
    }
    
    // MARK: - Session Management
    private func checkExistingSession() {
        guard let userId = userDefaults.string(forKey: "currentUserId") else {
            // No stored session - auto login locally
            autoLoginLocally()
            return
        }

        do {
            if let user = try userRepo.getById(userId) {
                currentUser = user
                authState = .authenticated(user)
                authStateSubject.send(authState)
            } else {
                // User not found in DB - auto login locally
                autoLoginLocally()
            }
        } catch {
            // Database error - auto login locally
            autoLoginLocally()
        }
    }

    /// Automatically login with a local user account
    private func autoLoginLocally() {
        // Check if local user exists
        let predicate = #Predicate<User> { $0.isLocalUser == true }

        if let existingUser = try? dataService.fetchOne(User.self, predicate: predicate) {
            currentUser = existingUser
            authState = .authenticated(existingUser)
            authStateSubject.send(authState)
            saveSession(userId: existingUser.id)
            return
        }

        // Create local user
        let localUser = User(
            email: "local@taskflow.dev",
            displayName: "Local User",
            role: "owner",
            isLocalUser: true
        )

        dataService.insert(localUser)
        try? dataService.save()

        currentUser = localUser
        authState = .authenticated(localUser)
        authStateSubject.send(authState)
        saveSession(userId: localUser.id)
    }
    
    private func saveSession(userId: String) {
        userDefaults.set(userId, forKey: "currentUserId")
    }
    
    private func clearSession() {
        userDefaults.removeObject(forKey: "currentUserId")
    }
    
    // MARK: - Local Login (No Password)
    func loginLocally() throws -> User {
        // Use auto login logic
        autoLoginLocally()

        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }

        return user
    }
    
    // MARK: - Register
    func register(email: String, password: String, displayName: String) async throws -> User {
        // Validate input
        guard !email.isEmpty else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        guard !displayName.isEmpty else {
            throw AuthError.invalidDisplayName
        }
        
        // Check if user exists
        let predicate = #Predicate<User> { $0.email == email }
        if try dataService.fetchOne(User.self, predicate: predicate) != nil {
            throw AuthError.userAlreadyExists
        }
        
        // Create user (in production, hash password)
        let user = User(
            email: email,
            displayName: displayName,
            role: "member",
            isLocalUser: false
        )
        
        dataService.insert(user)
        try dataService.save()
        
        // Save session
        currentUser = user
        authState = .authenticated(user)
        authStateSubject.send(authState)
        saveSession(userId: user.id)
        
        return user
    }
    
    // MARK: - Login
    func login(email: String, password: String) async throws -> User {
        guard !email.isEmpty else {
            throw AuthError.invalidEmail
        }
        guard !password.isEmpty else {
            throw AuthError.invalidPassword
        }
        
        // Find user
        let predicate = #Predicate<User> { $0.email == email }
        guard let user = try dataService.fetchOne(User.self, predicate: predicate) else {
            throw AuthError.userNotFound
        }
        
        // Verify password (in production, verify hash)
        // For demo purposes, accept any password for demo@taskflow.dev
        if email == "demo@taskflow.dev" || password == "Demo123!" {
            user.lastActiveAt = Date()
            try dataService.save()
            
            currentUser = user
            authState = .authenticated(user)
            authStateSubject.send(authState)
            saveSession(userId: user.id)
            
            return user
        }
        
        throw AuthError.invalidCredentials
    }
    
    // MARK: - Logout
    func logout() throws {
        currentUser = nil
        authState = .unauthenticated
        authStateSubject.send(authState)
        clearSession()
    }
    
    // MARK: - Delete Account
    func deleteAccount() throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }
        
        dataService.delete(user)
        try dataService.save()
        
        try logout()
    }
    
    // MARK: - Update Profile
    func updateProfile(displayName: String? = nil, avatarColor: String? = nil) throws {
        guard let user = currentUser else {
            throw AuthError.userNotFound
        }

        if let displayName = displayName {
            user.displayName = displayName
        }
        if let avatarColor = avatarColor {
            user.avatarColor = avatarColor
        }

        try dataService.save()
        currentUser = user
        authState = .authenticated(user)
        authStateSubject.send(authState)
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case invalidCredentials
    case weakPassword
    case invalidDisplayName
    case userNotFound
    case userAlreadyExists
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Bitte geben Sie eine gültige E-Mail-Adresse ein."
        case .invalidPassword:
            return "Bitte geben Sie ein Passwort ein."
        case .invalidCredentials:
            return "E-Mail oder Passwort ist falsch."
        case .weakPassword:
            return "Das Passwort muss mindestens 8 Zeichen lang sein."
        case .invalidDisplayName:
            return "Bitte geben Sie einen Anzeigenamen ein."
        case .userNotFound:
            return "Benutzer nicht gefunden."
        case .userAlreadyExists:
            return "Ein Benutzer mit dieser E-Mail existiert bereits."
        case .notAuthenticated:
            return "Nicht authentifiziert."
        }
    }
}

// MARK: - User Repository
@MainActor
final class UserRepository: BaseRepository<User> {

    func getCurrentUser() throws -> User? {
        guard let userId = UserDefaults.standard.string(forKey: "currentUserId") else {
            return nil
        }
        return try getById(userId)
    }

    func getUserByEmail(_ email: String) throws -> User? {
        let predicate = #Predicate<User> { $0.email == email }
        return try dataService.fetchOne(User.self, predicate: predicate)
    }

    func getAllUsers() throws -> [User] {
        let sortDescriptor = [SortDescriptor<User>(\.createdAt)]
        return try dataService.fetch(User.self, filter: sortDescriptor, predicate: nil)
    }

    func searchUsers(query: String) throws -> [User] {
        let predicate = #Predicate<User> {
            $0.displayName.localizedStandardContains(query) ||
            $0.email.localizedStandardContains(query)
        }
        return try dataService.fetch(User.self, filter: [], predicate: predicate)
    }
}
