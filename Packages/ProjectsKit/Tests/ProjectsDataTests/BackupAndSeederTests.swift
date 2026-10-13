import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("Backup, CSV and sample data")
struct BackupAndSeederTests {
    @Test func seederCreatesAConsistentDataSet() throws {
        let stack = try TestStack()
        let seeder = DemoDataSeeder(environment: stack.environment)
        #expect(try seeder.isStoreEmpty())

        try seeder.seedIfEmpty()
        let taskCount = try stack.count(TaskItem.self)
        #expect(try stack.count(Workspace.self) == 2)
        #expect(taskCount == 9)

        try seeder.seedIfEmpty()
        #expect(try stack.count(TaskItem.self) == taskCount, "Seeding twice is a no-op")

        let tasks = try stack.context.fetch(FetchDescriptor<TaskItem>())
        for task in tasks {
            #expect(task.column?.status == task.status, "\(task.title) is in a column that does not match its status")
            #expect(task.column?.project?.id == task.project?.id)
        }
    }

    @Test("Export → replace import reproduces the same backup")
    func backupRoundTrip() throws {
        let source = try TestStack()
        try DemoDataSeeder(environment: source.environment).seed()
        let original = try source.backup.makeBackup()
        let json = try source.backup.exportJSON()

        let target = try TestStack()
        _ = try target.workspaces.create(name: "Will be replaced")
        let summary = try target.backup.importJSON(json, mode: .replaceAll)

        #expect(summary.importedWorkspaces == original.workspaces.count)
        #expect(summary.importedTasks == original.workspaces.flatMap(\.projects).flatMap(\.tasks).count)
        let restored = try target.backup.makeBackup()
        #expect(normalized(restored) == normalized(original))
        #expect(target.observer.deletedIDs.isEmpty, "The replaced workspace had no tasks")
    }

    @Test func mergeSkipsExistingWorkspaces() throws {
        let stack = try TestStack()
        try DemoDataSeeder(environment: stack.environment).seed()
        let json = try stack.backup.exportJSON()

        let summary = try stack.backup.importJSON(json, mode: .merge)

        #expect(summary.importedWorkspaces == 0)
        #expect(summary.skippedWorkspaces == 2)
        #expect(try stack.count(Workspace.self) == 2)
    }

    @Test func importRejectsGarbageWithoutTouchingData() throws {
        let stack = try TestStack()
        _ = try stack.workspaces.create(name: "Keep me")
        #expect(throws: ProjectsError.corruptBackup) {
            try stack.backup.importJSON(Data("nope".utf8), mode: .replaceAll)
        }
        #expect(try stack.count(Workspace.self) == 1)
    }

    @Test func importRepairsDanglingReferences() throws {
        let stack = try TestStack()
        var document = try BackupDocumentFactory.minimal()
        document.workspaces[0].projects[0].tasks[0].columnID = UUID()
        document.workspaces[0].projects[0].tasks[0].labelIDs = [UUID()]
        document.workspaces[0].projects[0].tasks[0].blockedByIDs = [UUID(), document.workspaces[0].projects[0].tasks[0].id]

        try stack.backup.restore(document, mode: .merge)

        let task = try #require(try stack.context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(task.column?.status == task.status)
        #expect(task.labelIDs.isEmpty)
        #expect(task.blockers.isEmpty)
    }

    @Test func csvContainsOneRowPerTask() throws {
        let stack = try TestStack()
        try DemoDataSeeder(environment: stack.environment).seed()
        let data = try CSVExportService(environment: stack.environment).exportTasks()
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        let rows = text.split(separator: "\r\n", omittingEmptySubsequences: true)
        #expect(rows.count == (try stack.count(TaskItem.self)) + 1)
    }

    /// Removes values that legitimately differ between export runs.
    private func normalized(_ document: BackupDocument) -> BackupDocument {
        var copy = document
        copy.exportedAt = .distantPast
        copy.workspaces = copy.workspaces.map { workspace in
            var workspace = workspace
            workspace.projects = workspace.projects.map { project in
                var project = project
                project.tasks = project.tasks.sorted { $0.id.uuidString < $1.id.uuidString }
                return project
            }
            return workspace
        }
        return copy
    }
}

enum BackupDocumentFactory {
    static func minimal() throws -> BackupDocument {
        let columnID = UUID()
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        return BackupDocument(exportedAt: date, workspaces: [
            .init(
                id: UUID(), name: "W", details: "", colorHex: "#000000", symbolName: "briefcase", isArchived: false,
                createdAt: date, labels: [], templates: [],
                projects: [.init(
                    id: UUID(), name: "P", details: "", colorHex: "#000000", symbolName: "folder", status: .active,
                    isArchived: false, startDate: nil, dueDate: nil, createdAt: date,
                    columns: [.init(id: columnID, name: "Doing", colorHex: "#000000", order: 0, status: .inProgress)],
                    customFields: [],
                    tasks: [.init(
                        id: UUID(), title: "T", details: "", status: .inProgress, priority: .medium, columnID: columnID,
                        order: 0, startDate: nil, dueDate: nil, completedAt: nil, reminderDate: nil, estimatedHours: nil,
                        recurrence: nil, createdAt: date, updatedAt: date, labelIDs: [], blockedByIDs: [], subtasks: [],
                        comments: [], customFieldValues: []
                    )]
                )]
            ),
        ])
    }
}
