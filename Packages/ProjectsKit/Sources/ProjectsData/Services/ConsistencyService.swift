import Foundation
import SwiftData
import ProjectsCore

/// What ``ConsistencyService/repair()`` changed.
public struct RepairReport: Equatable, Sendable {
    /// Tasks moved into a column that matches their status.
    public var movedToMatchingColumn = 0
    /// Tasks whose status was set to their column's status because the project has no column for it.
    public var statusAdoptedFromColumn = 0
    /// Tasks whose completion date did not match their status.
    public var completionDateFixed = 0
    /// Columns whose tasks shared sort keys and were renumbered.
    public var columnsRenumbered = 0

    public var isEmpty: Bool { self == RepairReport() }
}

/// Restores the invariants of the board after changes the services could not control: iCloud
/// merges of edits made on two devices, backups written by other versions, or crashes mid-write.
///
/// Invariants:
/// 1. A task lies in a column of its own project, and that column represents the task's status.
///    The status is the source of truth; only when the project has no column for it does the task
///    adopt the status of the column it is in.
/// 2. `completedAt` is set exactly for completed tasks.
/// 3. Tasks of a column have distinct sort keys, so the order is stable on every device.
public final class ConsistencyService {
    private let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    /// Checks every task and fixes what is inconsistent. Saves only when something changed.
    @discardableResult
    public func repair() throws -> RepairReport {
        var report = RepairReport()
        var changed: [TaskItem] = []
        let projects = try environment.fetch(FetchDescriptor<Project>())

        for project in projects {
            let columns = project.sortedColumns
            guard !columns.isEmpty else { continue }
            for task in project.taskList where repair(task, columns: columns, report: &report) {
                changed.append(task)
            }
            for column in columns where hasDuplicateKeys(column) {
                for (task, key) in zip(column.sortedTasks, SparseOrder.renumbered(count: column.sortedTasks.count)) {
                    task.order = key
                }
                report.columnsRenumbered += 1
            }
        }

        if !report.isEmpty {
            try environment.save(changed: changed)
            Log.services.notice("Repaired board consistency: \(String(describing: report), privacy: .public)")
        }
        return report
    }

    /// Fixes column, status and completion date of one task.
    /// - Returns: `true` when the task changed.
    private func repair(_ task: TaskItem, columns: [BoardColumn], report: inout RepairReport) -> Bool {
        var didChange = false
        if let target = column(for: task, in: columns) {
            task.column = target
            task.order = SparseOrder.appendKey(after: target.sortedTasks.filter { $0.id != task.id }.map(\.order))
            report.movedToMatchingColumn += 1
            didChange = true
        } else if let column = task.column, column.status != task.status {
            TaskStatusTransition.apply(column.status, to: task, now: environment.now())
            report.statusAdoptedFromColumn += 1
            didChange = true
        }
        if task.isCompleted != (task.completedAt != nil) {
            task.completedAt = task.isCompleted ? task.updatedAt : nil
            report.completionDateFixed += 1
            didChange = true
        }
        return didChange
    }

    /// The column a task has to move to, or `nil` when it may stay where it is.
    private func column(for task: TaskItem, in columns: [BoardColumn]) -> BoardColumn? {
        let current = task.column
        let isInOwnProject = current.map { column in columns.contains { $0.id == column.id } } ?? false
        if isInOwnProject, current?.status == task.status {
            return nil
        }
        if let matching = columns.first(where: { $0.status == task.status }) {
            return matching
        }
        // No column represents the status: keep a column of the own project, or take the first one.
        return isInOwnProject ? nil : columns.first
    }

    private func hasDuplicateKeys(_ column: BoardColumn) -> Bool {
        let keys = (column.tasks ?? []).map(\.order)
        return Set(keys).count != keys.count
    }
}
