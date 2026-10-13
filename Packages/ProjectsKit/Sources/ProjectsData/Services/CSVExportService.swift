import Foundation
import SwiftData
import ProjectsCore

/// Exports tasks as CSV for spreadsheets. Column headers and enum values use the current
/// language; dates use ISO 8601 so that every spreadsheet application parses them.
public final class CSVExportService {
    private let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    public func exportTasks() throws -> Data {
        let tasks = try environment.fetch(FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.createdAt)]))
        return Self.makeCSV(for: tasks)
    }

    static func makeCSV(for tasks: [TaskItem]) -> Data {
        var writer = CSVWriter(header: [
            String(localized: "Title", bundle: .module, comment: "CSV column"),
            String(localized: "Status", bundle: .module, comment: "CSV column"),
            String(localized: "Priority", bundle: .module, comment: "CSV column"),
            String(localized: "Workspace", bundle: .module, comment: "CSV column"),
            String(localized: "Project", bundle: .module, comment: "CSV column"),
            String(localized: "Labels", bundle: .module, comment: "CSV column"),
            String(localized: "Due date", bundle: .module, comment: "CSV column"),
            String(localized: "Completed at", bundle: .module, comment: "CSV column"),
            String(localized: "Estimated hours", bundle: .module, comment: "CSV column"),
            String(localized: "Subtasks", bundle: .module, comment: "CSV column"),
            String(localized: "People", bundle: .module, comment: "CSV column: people involved in the task"),
            String(localized: "Open questions", bundle: .module, comment: "CSV column"),
        ])
        for task in tasks {
            writer.append([
                task.title,
                task.status.title,
                task.priority.title,
                task.project?.workspace?.name ?? "",
                task.project?.name ?? "",
                task.sortedLabels.map(\.name).joined(separator: ", "),
                task.dueDate.map { $0.formatted(.iso8601) } ?? "",
                task.completedAt.map { $0.formatted(.iso8601) } ?? "",
                task.estimatedHours.map { $0.description } ?? "",
                task.subtaskCount == 0 ? "" : "\(task.completedSubtaskCount)/\(task.subtaskCount)",
                task.involvedPeople.joined(separator: ", "),
                task.openQuestionCount == 0 ? "" : String(task.openQuestionCount),
            ])
        }
        return writer.makeData()
    }
}
