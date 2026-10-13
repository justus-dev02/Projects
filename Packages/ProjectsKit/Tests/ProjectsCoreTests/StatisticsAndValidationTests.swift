import Foundation
import Testing
@testable import ProjectsCore

@Suite("TaskStatistics")
struct TaskStatisticsTests {
    let calendar = TestCalendars.germany

    @Test func emptyInput() {
        let stats = TaskStatistics(tasks: [], now: .now, calendar: calendar)
        #expect(stats.total == 0)
        #expect(stats.completionRate == 0)
    }

    @Test func aggregates() {
        let now = calendar.date(2026, 3, 14, 12)
        let tasks = [
            TaskSnapshot(status: .done, completedAt: calendar.date(2026, 3, 12)),
            TaskSnapshot(status: .done, dueDate: calendar.date(2026, 1, 1), completedAt: calendar.date(2026, 1, 2)),
            TaskSnapshot(status: .inProgress, dueDate: calendar.date(2026, 3, 13)),
            TaskSnapshot(status: .review, dueDate: calendar.date(2026, 3, 14, 18)),
            TaskSnapshot(status: .todo, dueDate: calendar.date(2026, 3, 14, 8)),
        ]
        let stats = TaskStatistics(tasks: tasks, now: now, calendar: calendar)
        #expect(stats.total == 5)
        #expect(stats.completed == 2)
        #expect(stats.open == 3)
        #expect(stats.inProgress == 2)
        #expect(stats.overdue == 2, "Due yesterday and due this morning, completed tasks never count")
        #expect(stats.dueToday == 2)
        #expect(stats.completedLast7Days == 1)
        #expect(stats.completionRate == 0.4)
    }
}

@Suite("Validation")
struct ValidationTests {
    @Test func trimsNames() throws {
        #expect(try Validation.name("  Sprint 1 \n", field: .projectName) == "Sprint 1")
    }

    @Test func rejectsEmptyNames() {
        #expect(throws: ProjectsError.emptyField(.taskTitle)) {
            try Validation.name(" \n\t", field: .taskTitle)
        }
    }

    @Test func rejectsLongNames() {
        let long = String(repeating: "x", count: Validation.maxNameLength + 1)
        #expect(throws: ProjectsError.fieldTooLong(.workspaceName, maxLength: Validation.maxNameLength)) {
            try Validation.name(long, field: .workspaceName)
        }
    }

    @Test func attachmentLimit() throws {
        try AttachmentPolicy.validate(byteCount: AttachmentPolicy.maxBytes)
        #expect(throws: ProjectsError.attachmentTooLarge(maxBytes: AttachmentPolicy.maxBytes)) {
            try AttachmentPolicy.validate(byteCount: AttachmentPolicy.maxBytes + 1)
        }
    }

    @Test("Every error has a user facing description")
    func errorDescriptions() {
        let errors: [ProjectsError] = [
            .emptyField(.taskTitle), .fieldTooLong(.projectName, maxLength: 5), .notFound(.task),
            .cannotDeleteLastColumn, .selfDependency, .dependencyCycle, .dependencyAcrossProjects,
            .invalidCustomFieldValue(fieldName: "x"), .requiredCustomFieldMissing(fieldName: "x"),
            .customFieldNeedsOptions, .attachmentTooLarge(maxBytes: 1024), .unsupportedBackupVersion(9),
            .corruptBackup, .persistenceFailed, .storeUnavailable,
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
        #expect(ProjectsError.persistenceFailed.recoverySuggestion != nil)
    }
}
