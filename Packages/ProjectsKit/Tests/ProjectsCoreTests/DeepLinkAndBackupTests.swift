import Foundation
import Testing
@testable import ProjectsCore

@Suite("DeepLink")
struct DeepLinkTests {
    @Test(arguments: [
        DeepLink.task(UUID()), .project(UUID()), .workspace(UUID()), .newTask, .today,
    ])
    func roundTrip(link: DeepLink) {
        #expect(DeepLink(url: link.url) == link)
    }

    @Test func parsesCaseInsensitiveSchemeAndHost() throws {
        let id = UUID()
        let url = try #require(URL(string: "Projects://TASK/\(id.uuidString)"))
        #expect(DeepLink(url: url) == .task(id))
    }

    @Test(arguments: [
        "https://task/123", "projects://task/not-a-uuid", "projects://task", "projects://unknown/x", "projects:",
    ])
    func rejectsInvalidURLs(string: String) throws {
        let url = try #require(URL(string: string))
        #expect(DeepLink(url: url) == nil)
    }
}

@Suite("BackupDocument")
struct BackupDocumentTests {
    static func sample() -> BackupDocument {
        let labelID = UUID(), columnID = UUID(), fieldID = UUID(), blockerID = UUID()
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let blocker = BackupDocument.TaskRecord(
            id: blockerID, title: "Blocker", details: "", status: .done, priority: .low, columnID: columnID,
            order: 0, startDate: nil, dueDate: nil, completedAt: date, reminderDate: nil, estimatedHours: nil,
            recurrence: nil, createdAt: date, updatedAt: date, labelIDs: [], blockedByIDs: [], subtasks: [],
            comments: [], customFieldValues: []
        )
        let task = BackupDocument.TaskRecord(
            id: UUID(), title: "Write \"tests\"", details: "Ä, Ö, Ü", status: .inProgress, priority: .urgent,
            columnID: columnID, order: 1, startDate: date, dueDate: date, completedAt: nil, reminderDate: date,
            estimatedHours: 2.5, recurrence: RecurrenceRule(frequency: .weekly, interval: 2), createdAt: date,
            updatedAt: date, labelIDs: [labelID], blockedByIDs: [blockerID],
            subtasks: [.init(id: UUID(), title: "Sub", isCompleted: true, order: 0)],
            comments: [.init(id: UUID(), text: "Note", createdAt: date, updatedAt: date)],
            customFieldValues: [.init(fieldID: fieldID, value: "42.0")]
        )
        let project = BackupDocument.ProjectRecord(
            id: UUID(), name: "App", details: "", colorHex: "#5B5BD6", symbolName: "folder", status: .active,
            isArchived: false, startDate: nil, dueDate: date, createdAt: date,
            columns: [.init(id: columnID, name: "Doing", colorHex: "#000000", order: 0, status: .inProgress)],
            customFields: [.init(id: fieldID, name: "Points", type: .number, options: [], isRequired: false, order: 0)],
            tasks: [blocker, task]
        )
        let workspace = BackupDocument.WorkspaceRecord(
            id: UUID(), name: "Work", details: "", colorHex: "#5B5BD6", symbolName: "briefcase", isArchived: false,
            createdAt: date, labels: [.init(id: labelID, name: "Bug", colorHex: "#FF0000", order: 0)],
            templates: [.init(
                id: UUID(), name: "Bug report", category: .bug, taskTitle: "Bug", taskDetails: "", priority: .high,
                estimatedHours: 1, subtaskTitles: ["Reproduce"], usageCount: 3
            )],
            projects: [project]
        )
        return BackupDocument(exportedAt: date, workspaces: [workspace])
    }

    @Test func roundTrip() throws {
        let document = Self.sample()
        let decoded = try BackupDocument.decode(from: document.encoded())
        #expect(decoded == document)
    }

    @Test func rejectsNewerVersions() throws {
        var document = Self.sample()
        document.formatVersion = BackupDocument.currentVersion + 1
        let data = try document.encoded()
        #expect(throws: ProjectsError.unsupportedBackupVersion(BackupDocument.currentVersion + 1)) {
            try BackupDocument.decode(from: data)
        }
    }

    @Test(arguments: ["", "{}", "[1,2]", "{\"formatVersion\": 1}", "not json"])
    func rejectsCorruptData(text: String) {
        #expect(throws: ProjectsError.corruptBackup) {
            try BackupDocument.decode(from: Data(text.utf8))
        }
    }
}

@Suite("CSVWriter")
struct CSVWriterTests {
    @Test(arguments: [
        ("plain", "plain"),
        ("a,b", "\"a,b\""),
        ("say \"hi\"", "\"say \"\"hi\"\"\""),
        ("line\nbreak", "\"line\nbreak\""),
        ("semi;colon", "\"semi;colon\""),
        ("", ""),
    ])
    func escaping(input: String, expected: String) {
        #expect(CSVWriter.escape(input) == expected)
    }

    @Test func documentHasBOMAndCRLF() throws {
        var writer = CSVWriter(header: ["Title", "Status"])
        writer.append(["Äpfel, Birnen", "Done"])
        let data = writer.makeData()
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
        #expect(text == "Title,Status\r\n\"Äpfel, Birnen\",Done\r\n")
    }
}
