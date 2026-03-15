//
//  DataServiceTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for DataService
//

import XCTest
@testable import Projects
import SwiftData

@MainActor
final class DataServiceTests: XCTestCase {
    
    var dataService: DataService!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            User.self,
            Workspace.self,
            Project.self,
            Task.self,
            Label.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = container.mainContext
        dataService = DataService(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        dataService = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Insert Tests
    
    func testInsert_User() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        
        // When
        dataService.insert(user)
        
        // Then
        let predicate = #Predicate<User> { $0.email == "test@example.com" }
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.displayName, "Test User")
    }
    
    func testInsert_Workspace() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        
        // When
        dataService.insert(workspace)
        
        // Then
        let predicate = #Predicate<Workspace> { $0.name == "Test Workspace" }
        let fetched = try dataService.fetchOne(Workspace.self, predicate: predicate)
        XCTAssertNotNil(fetched)
    }
    
    func testInsert_Project() throws {
        // Given
        let project = Project(name: "Test Project")
        
        // When
        dataService.insert(project)
        
        // Then
        let predicate = #Predicate<Project> { $0.name == "Test Project" }
        let fetched = try dataService.fetchOne(Project.self, predicate: predicate)
        XCTAssertNotNil(fetched)
    }
    
    func testInsert_Task() throws {
        // Given
        let task = Task(title: "Test Task")
        
        // When
        dataService.insert(task)
        
        // Then
        let predicate = #Predicate<Task> { $0.title == "Test Task" }
        let fetched = try dataService.fetchOne(Task.self, predicate: predicate)
        XCTAssertNotNil(fetched)
    }
    
    // MARK: - Fetch Tests
    
    func testFetch_AllUsers() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let user3 = User(email: "user3@example.com", displayName: "User 3")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        // When
        let users = try dataService.fetch(User.self, filter: [], predicate: nil)
        
        // Then
        XCTAssertEqual(users.count, 3)
    }
    
    func testFetch_WithPredicate() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1", role: "admin")
        let user2 = User(email: "user2@example.com", displayName: "User 2", role: "member")
        let user3 = User(email: "user3@example.com", displayName: "User 3", role: "admin")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        let predicate = #Predicate<User> { $0.role == "admin" }
        
        // When
        let users = try dataService.fetch(User.self, filter: [], predicate: predicate)
        
        // Then
        XCTAssertEqual(users.count, 2)
    }
    
    func testFetch_WithSortDescriptor() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "Charlie", createdAt: Date().addingTimeInterval(-3600))
        let user2 = User(email: "user2@example.com", displayName: "Alice", createdAt: Date().addingTimeInterval(-7200))
        let user3 = User(email: "user3@example.com", displayName: "Bob", createdAt: Date())
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        let sortDescriptor = [SortDescriptor<User>(\.displayName)]
        
        // When
        let users = try dataService.fetch(User.self, filter: sortDescriptor, predicate: nil)
        
        // Then
        XCTAssertEqual(users[0].displayName, "Alice")
        XCTAssertEqual(users[1].displayName, "Bob")
        XCTAssertEqual(users[2].displayName, "Charlie")
    }
    
    func testFetch_WithReverseSortDescriptor() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "Alice")
        let user2 = User(email: "user2@example.com", displayName: "Bob")
        let user3 = User(email: "user3@example.com", displayName: "Charlie")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        let sortDescriptor = [SortDescriptor<User>(\.displayName, order: .reverse)]
        
        // When
        let users = try dataService.fetch(User.self, filter: sortDescriptor, predicate: nil)
        
        // Then
        XCTAssertEqual(users[0].displayName, "Charlie")
        XCTAssertEqual(users[1].displayName, "Bob")
        XCTAssertEqual(users[2].displayName, "Alice")
    }
    
    // MARK: - FetchOne Tests
    
    func testFetchOne_Found() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        dataService.insert(user)
        
        let predicate = #Predicate<User> { $0.email == "test@example.com" }
        
        // When
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        
        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.displayName, "Test User")
    }
    
    func testFetchOne_NotFound() throws {
        // Given
        let predicate = #Predicate<User> { $0.email == "nonexistent@example.com" }
        
        // When
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        
        // Then
        XCTAssertNil(fetched)
    }
    
    // MARK: - Delete Tests
    
    func testDelete_SingleItem() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        dataService.insert(user)
        
        // When
        dataService.delete(user)
        try dataService.save()
        
        // Then
        let predicate = #Predicate<User> { $0.email == "test@example.com" }
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        XCTAssertNil(fetched)
    }
    
    func testDelete_MultipleItems() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let user3 = User(email: "user3@example.com", displayName: "User 3")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        // When
        dataService.delete(user1)
        dataService.delete(user2)
        try dataService.save()
        
        // Then
        let users = try dataService.fetch(User.self, filter: [], predicate: nil)
        XCTAssertEqual(users.count, 1)
    }
    
    func testDeleteAll_WithPredicate() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1", role: "admin")
        let user2 = User(email: "user2@example.com", displayName: "User 2", role: "member")
        let user3 = User(email: "user3@example.com", displayName: "User 3", role: "admin")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        let predicate = #Predicate<User> { $0.role == "admin" }
        
        // When
        try dataService.deleteAll(User.self, predicate: predicate)
        try dataService.save()
        
        // Then
        let users = try dataService.fetch(User.self, filter: [], predicate: nil)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users[0].role, "member")
    }
    
    func testDeleteAll_WithoutPredicate() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        dataService.insert(user1)
        dataService.insert(user2)
        
        // When
        try dataService.deleteAll(User.self, predicate: nil)
        try dataService.save()
        
        // Then
        let users = try dataService.fetch(User.self, filter: [], predicate: nil)
        XCTAssertEqual(users.count, 0)
    }
    
    // MARK: - Save Tests
    
    func testSave_AfterInsert() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        dataService.insert(user)
        
        // When
        try dataService.save()
        
        // Then
        let predicate = #Predicate<User> { $0.email == "test@example.com" }
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        XCTAssertNotNil(fetched)
    }
    
    func testSave_UpdatesExistingItem() throws {
        // Given
        let user = User(email: "test@example.com", displayName: "Test User")
        dataService.insert(user)
        try dataService.save()
        
        // When
        user.displayName = "Updated User"
        try dataService.save()
        
        // Then
        let predicate = #Predicate<User> { $0.email == "test@example.com" }
        let fetched = try dataService.fetchOne(User.self, predicate: predicate)
        XCTAssertEqual(fetched?.displayName, "Updated User")
    }
    
    // MARK: - Batch Operations Tests
    
    func testPerformBatch_InsertMultiple() async throws {
        // When
        try await dataService.performBatch { context in
            let user1 = User(email: "user1@example.com", displayName: "User 1")
            let user2 = User(email: "user2@example.com", displayName: "User 2")
            let user3 = User(email: "user3@example.com", displayName: "User 3")
            context.insert(user1)
            context.insert(user2)
            context.insert(user3)
        }
        
        // Then
        let users = try dataService.fetch(User.self, filter: [], predicate: nil)
        XCTAssertEqual(users.count, 3)
    }
    
    func testPerformBatch_MixedOperations() async throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        dataService.insert(user1)
        dataService.insert(user2)
        try dataService.save()
        
        // When
        try await dataService.performBatch { context in
            // Insert new user
            let user3 = User(email: "user3@example.com", displayName: "User 3")
            context.insert(user3)
            
            // Update existing user
            user1.displayName = "Updated User 1"
            
            // Delete user
            context.delete(user2)
        }
        
        // Then
        let users = try dataService.fetch(User.self, filter: [], predicate: nil)
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users.first { $0.email == "user1@example.com" }?.displayName, "Updated User 1")
    }
    
    // MARK: - Relationship Tests
    
    func testInsert_WithRelationships() throws {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let project = Project(name: "Test Project")
        project.workspace = workspace
        
        // When
        dataService.insert(workspace)
        dataService.insert(project)
        try dataService.save()
        
        // Then
        let projectPredicate = #Predicate<Project> { $0.name == "Test Project" }
        let fetchedProject = try dataService.fetchOne(Project.self, predicate: projectPredicate)
        XCTAssertEqual(fetchedProject?.workspace?.name, "Test Workspace")
    }
    
    func testInsert_TaskWithSubtasks() throws {
        // Given
        let task = Task(title: "Parent Task")
        let subtask1 = Subtask(title: "Subtask 1")
        let subtask2 = Subtask(title: "Subtask 2")
        subtask1.task = task
        subtask2.task = task
        task.subtasks = [subtask1, subtask2]
        
        // When
        dataService.insert(task)
        try dataService.save()
        
        // Then
        let taskPredicate = #Predicate<Task> { $0.title == "Parent Task" }
        let fetchedTask = try dataService.fetchOne(Task.self, predicate: taskPredicate)
        XCTAssertEqual(fetchedTask?.subtasks?.count, 2)
    }
    
    func testInsert_TaskWithComments() throws {
        // Given
        let task = Task(title: "Parent Task")
        let author = User(email: "author@example.com", displayName: "Author")
        let comment1 = Comment(content: "Comment 1")
        let comment2 = Comment(content: "Comment 2")
        comment1.author = author
        comment2.author = author
        comment1.task = task
        comment2.task = task
        task.comments = [comment1, comment2]
        
        // When
        dataService.insert(author)
        dataService.insert(task)
        try dataService.save()
        
        // Then
        let taskPredicate = #Predicate<Task> { $0.title == "Parent Task" }
        let fetchedTask = try dataService.fetchOne(Task.self, predicate: taskPredicate)
        XCTAssertEqual(fetchedTask?.comments?.count, 2)
    }
    
    // MARK: - Count Tests
    
    func testCount_AllItems() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1")
        let user2 = User(email: "user2@example.com", displayName: "User 2")
        let user3 = User(email: "user3@example.com", displayName: "User 3")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        // When
        let count = try dataService.count(User.self, predicate: nil)
        
        // Then
        XCTAssertEqual(count, 3)
    }
    
    func testCount_WithPredicate() throws {
        // Given
        let user1 = User(email: "user1@example.com", displayName: "User 1", role: "admin")
        let user2 = User(email: "user2@example.com", displayName: "User 2", role: "member")
        let user3 = User(email: "user3@example.com", displayName: "User 3", role: "admin")
        dataService.insert(user1)
        dataService.insert(user2)
        dataService.insert(user3)
        
        let predicate = #Predicate<User> { $0.role == "admin" }
        
        // When
        let count = try dataService.count(User.self, predicate: predicate)
        
        // Then
        XCTAssertEqual(count, 2)
    }
    
    func testCount_WhenEmpty() throws {
        // When
        let count = try dataService.count(User.self, predicate: nil)
        
        // Then
        XCTAssertEqual(count, 0)
    }
}
