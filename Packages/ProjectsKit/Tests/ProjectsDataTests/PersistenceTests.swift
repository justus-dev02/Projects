import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("Persistence")
struct PersistenceTests {
    private func temporaryStoreURL() -> URL {
        URL.temporaryDirectory
            .appending(path: "ProjectsTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: PersistenceController.storeFileName)
    }

    @Test("Data survives closing and reopening an on-disk store through the migration plan")
    func reopenOnDiskStore() throws {
        let url = temporaryStoreURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        do {
            let container = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
            let environment = ServiceEnvironment(context: container.mainContext)
            try DemoDataSeeder(environment: environment).seed()
        }

        let reopened = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
        let tasks = try reopened.mainContext.fetch(FetchDescriptor<TaskItem>())
        #expect(!tasks.isEmpty)
        #expect(tasks.allSatisfy { $0.project != nil && $0.column != nil })
        #expect(tasks.contains { $0.recurrence != nil }, "Codable attributes are persisted")
    }

    @Test func destroyStoreRemovesAllFiles() throws {
        let url = temporaryStoreURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        do {
            let container = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
            _ = try WorkspaceService(environment: ServiceEnvironment(context: container.mainContext)).create(name: "W")
        }
        #expect(FileManager.default.fileExists(atPath: url.path()))

        try PersistenceController.destroyStore(at: url)

        #expect(!FileManager.default.fileExists(atPath: url.path()))
        let fresh = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
        #expect(try fresh.mainContext.fetchCount(FetchDescriptor<Workspace>()) == 0)
    }

    @Test func migrationPlanListsTheCurrentSchemaLast() {
        let last = ProjectsMigrationPlan.schemas.last
        #expect(last == CurrentSchema.self)
        #expect(CurrentSchema.models.count == 13)
    }

    @Test func saveFailuresAreReportedAsProjectsErrors() throws {
        let stack = try TestStack()
        // Validation errors never reach the store, so nothing is persisted.
        #expect(throws: ProjectsError.emptyField(.workspaceName)) {
            try stack.workspaces.create(name: "")
        }
        #expect(try stack.count(Workspace.self) == 0)
    }
}

@Suite("Store from before the rename")
struct LegacyStoreTests {
    private func makeDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "ProjectsLegacy-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("A store named after the former app name is adopted with its data")
    func legacyStoreIsAdopted() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appending(path: PersistenceController.legacyStoreFileName)
        do {
            let container = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(legacyURL)))
            _ = try WorkspaceService(environment: ServiceEnvironment(context: container.mainContext)).create(name: "Kept")
        }

        let storeURL = directory.appending(path: PersistenceController.storeFileName)
        PersistenceController.adoptLegacyStore(from: directory, to: storeURL)

        #expect(!FileManager.default.fileExists(atPath: legacyURL.path()))
        let container = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(storeURL)))
        let names = try container.mainContext.fetch(FetchDescriptor<Workspace>()).map(\.name)
        #expect(names == ["Kept"])
    }

    @Test func anExistingStoreIsNeverReplaced() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appending(path: PersistenceController.legacyStoreFileName)
        let storeURL = directory.appending(path: PersistenceController.storeFileName)
        try Data("old".utf8).write(to: legacyURL)
        try Data("current".utf8).write(to: storeURL)

        PersistenceController.adoptLegacyStore(from: directory, to: storeURL)

        #expect(try Data(contentsOf: storeURL) == Data("current".utf8))
        #expect(FileManager.default.fileExists(atPath: legacyURL.path()))
    }
}
