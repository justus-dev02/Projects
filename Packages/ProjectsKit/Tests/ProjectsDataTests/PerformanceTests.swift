import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

/// Guards the performance characteristics documented in `docs/PERFORMANCE.md`.
///
/// The limits are deliberately generous (CI machines are slow); the measured values are printed
/// so that regressions are visible long before a limit is hit.
@Suite("Performance", .serialized)
struct PerformanceTests {
    static let taskCount = 10_000

    private func seedLargeStore() throws -> TestStack {
        let stack = try TestStack()
        let (workspace, project) = try stack.makeProject()
        let labels = workspace.sortedLabels
        let columns = project.sortedColumns
        let context = stack.context
        for index in 0..<Self.taskCount {
            let column = columns[index % columns.count]
            let task = TaskItem(
                title: "Task \(index)",
                details: index.isMultiple(of: 10) ? "Rechnung prüfen" : "",
                status: column.status,
                priority: TaskPriority(rawValue: index % 4) ?? .medium
            )
            task.order = index
            task.dueDate = stack.date(dayOffset: (index % 60) - 30)
            context.insert(task)
            task.project = project
            task.column = column
            if index.isMultiple(of: 3) {
                task.labels = [labels[index % labels.count]]
            }
        }
        try context.save()
        return stack
    }

    private func measure(_ label: String, _ block: () throws -> Void) rethrows -> Duration {
        let clock = ContinuousClock()
        let duration = try clock.measure(block)
        print("⏱ \(label): \(duration.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 1))))")
        return duration
    }

    @Test func dashboardSummaryWithTenThousandTasks() throws {
        let stack = try seedLargeStore()
        var summary = DashboardSummary.empty
        let duration = try measure("Dashboard summary (\(Self.taskCount) tasks)") {
            summary = try stack.dashboard.summary()
        }
        #expect(summary.openTasks + (try stack.context.fetchCount(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.statusRaw == "done" }
        ))) == Self.taskCount)
        #expect(duration < .seconds(1))
    }

    @Test func filteredAndPagedFetchWithTenThousandTasks() throws {
        let stack = try seedLargeStore()
        let filter = TaskFilter(searchText: "rechnung", priorities: [.high, .urgent], includeCompleted: false)
        var descriptor = TaskQueries.descriptor(filter: filter, sort: .dueDate, now: stack.now, calendar: stack.calendar, limit: 50)
        var page: [TaskItem] = []
        let duration = try measure("Filtered fetch, first page of 50") {
            page = try stack.context.fetch(descriptor)
        }
        #expect(page.count == 50)
        #expect(duration < .seconds(1))

        descriptor.fetchLimit = nil
        var total = 0
        _ = try measure("Filtered count") {
            total = try stack.context.fetchCount(descriptor)
        }
        #expect(total > 50)
    }

    @Test func backupOfTenThousandTasks() throws {
        let stack = try seedLargeStore()
        var data = Data()
        let duration = try measure("JSON export") {
            data = try stack.backup.exportJSON()
        }
        print("📦 Backup size: \(Int64(data.count).formatted(.byteCount(style: .file)))")
        #expect(duration < .seconds(10))
    }
}
