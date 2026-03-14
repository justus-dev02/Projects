//
//  DataService.swift
//  Projects
//
//  TaskFlow - Core Data Service
//

import Foundation
import SwiftData
import Combine

// MARK: - Data Service Protocol
protocol DataServiceProtocol {
    var modelContext: ModelContext { get }

    // Generic CRUD
    func fetch<T: PersistentModel>(_ type: T.Type, filter: [SortDescriptor<T>], predicate: Predicate<T>?) throws -> [T]
    func fetchOne<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws -> T?
    func insert<T: PersistentModel>(_ model: T)
    func delete<T: PersistentModel>(_ model: T)
    func deleteAll<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws
    func save() throws

    // Batch Operations
    func performBatch(_ operations: @escaping (ModelContext) -> Void) async throws
}

// MARK: - Data Service Implementation
@MainActor
final class DataService: DataServiceProtocol {
    static let shared = DataService()

    private let modelContainer: ModelContainer
    internal var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    // Combine Publishers
    private let objectWillChange = PassthroughSubject<Void, Never>()
    var changes: AnyPublisher<Void, Never> {
        objectWillChange.eraseToAnyPublisher()
    }
    
    init(modelContainer: ModelContainer? = nil) {
        if let container = modelContainer {
            self.modelContainer = container
        } else {
            // Create default container with all models
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
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            
            do {
                self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
    
    // MARK: - Generic Fetch
    func fetch<T: PersistentModel>(_ type: T.Type, filter: [SortDescriptor<T>] = [], predicate: Predicate<T>?) throws -> [T] {
        var fetchDescriptor = FetchDescriptor<T>(predicate: predicate)
        if !filter.isEmpty {
            fetchDescriptor.sortBy = filter
        }
        return try modelContext.fetch(fetchDescriptor)
    }

    func fetchOne<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws -> T? {
        let fetchDescriptor = FetchDescriptor<T>(predicate: predicate)
        let results = try modelContext.fetch(fetchDescriptor)
        return results.first
    }

    func count<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<T>(predicate: predicate))
    }

    // MARK: - Generic Insert
    func insert<T: PersistentModel>(_ model: T) {
        modelContext.insert(model)
        objectWillChange.send()
    }

    // MARK: - Generic Delete
    func delete<T: PersistentModel>(_ model: T) {
        modelContext.delete(model)
        objectWillChange.send()
    }

    func deleteAll<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>?) throws {
        try modelContext.delete(model: type, where: predicate)
        objectWillChange.send()
    }
    
    // MARK: - Save
    func save() throws {
        if modelContext.hasChanges {
            try modelContext.save()
            objectWillChange.send()
        }
    }
    
    // MARK: - Batch Operations
    func performBatch(_ operations: @escaping (ModelContext) -> Void) async throws {
        operations(modelContext)
        try save()
    }
    
    // MARK: - Import/Export
    // Note: SwiftData models don't conform to Codable by default
    // Export/Import functionality would require custom serialization

    // MARK: - Backup
    func createBackup() throws -> Data {
        // Placeholder - implement custom serialization if needed
        return Data()
    }

    func restoreBackup(from data: Data) async throws {
        // Placeholder - implement custom deserialization if needed
    }
}

// MARK: - Repository Pattern
protocol RepositoryProtocol {
    associatedtype ModelType: PersistentModel

    func getAll() throws -> [ModelType]
    func getById(_ id: String) throws -> ModelType?
    func create(_ model: ModelType) throws
    func update(_ model: ModelType) throws
    func delete(_ id: String) throws
}

// MARK: - Base Repository
@MainActor
class BaseRepository<T: PersistentModel>: RepositoryProtocol where T: Identifiable, T.ID == String {
    let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
    }

    func getAll() throws -> [T] {
        try dataService.fetch(T.self, filter: [], predicate: nil)
    }

    func getById(_ id: String) throws -> T? {
        let predicate = #Predicate<T> { $0.id == id }
        return try dataService.fetchOne(T.self, predicate: predicate)
    }

    func create(_ model: T) throws {
        dataService.insert(model)
        try dataService.save()
    }

    func update(_ model: T) throws {
        // SwiftData automatically tracks changes
        try dataService.save()
    }

    func delete(_ id: String) throws {
        if let model = try getById(id) {
            dataService.delete(model)
            try dataService.save()
        }
    }

    func deleteAll(where predicate: Predicate<T>?) throws {
        try dataService.deleteAll(T.self, predicate: predicate)
    }
}
