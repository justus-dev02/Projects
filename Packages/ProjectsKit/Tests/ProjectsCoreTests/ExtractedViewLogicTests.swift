import Foundation
import Testing
@testable import ProjectsCore

@Suite("QuickFilter")
struct QuickFilterTests {
    private let base = TaskFilter(includeCompleted: false)

    @Test func openIsActiveWithoutDueOrStatusCriteria() {
        #expect(QuickFilter.open.isActive(in: base))
        #expect(!QuickFilter.overdue.isActive(in: base))
    }

    @Test func tappingATileTogglesItsCriterion() {
        let overdue = QuickFilter.overdue.toggled(in: base)
        #expect(overdue.due == .overdue)
        #expect(QuickFilter.overdue.isActive(in: overdue))
        #expect(!QuickFilter.open.isActive(in: overdue))
        #expect(QuickFilter.overdue.toggled(in: overdue).due == .any)
    }

    @Test func dueTilesReplaceEachOther() {
        let today = QuickFilter.dueToday.toggled(in: QuickFilter.overdue.toggled(in: base))
        #expect(today.due == .today)
    }

    @Test func inProgressSetsTheStatusAndOpenClearsEverything() {
        var filter = QuickFilter.inProgress.toggled(in: base)
        filter = QuickFilter.dueToday.toggled(in: filter)
        #expect(filter.statuses == [.inProgress])
        #expect(filter.due == .today)
        let open = QuickFilter.open.toggled(in: filter)
        #expect(open.statuses.isEmpty && open.due == .any)
    }

    @Test func otherCriteriaAreKept() {
        var filter = base
        filter.searchText = "report"
        filter.priorities = [.urgent]
        let result = QuickFilter.overdue.toggled(in: filter)
        #expect(result.searchText == "report")
        #expect(result.priorities == [.urgent])
        #expect(!result.includeCompleted)
    }

    @Test func refinementsIgnoreHidingCompletedTasks() {
        #expect(base.refinementCount == 0)
        #expect(QuickFilter.overdue.toggled(in: base).refinementCount == 1)
        #expect(TaskFilter(due: .today).refinementCount == 1)
    }
}

@Suite("TaskOrdering")
struct TaskOrderingTests {
    private struct Item: TaskFilterable {
        var title: String
        var details = ""
        var status = TaskStatus.todo
        var priority: TaskPriority
        var dueDate: Date?
        var labelIDs: Set<UUID> = []
    }

    @Test func priorityThenDueDateThenTitle() {
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let items = [
            Item(title: "B", priority: .medium),
            Item(title: "Late", priority: .high, dueDate: late),
            Item(title: "A", priority: .medium),
            Item(title: "Urgent", priority: .urgent),
            Item(title: "Early", priority: .high, dueDate: early),
            Item(title: "Dated", priority: .medium, dueDate: late),
        ]
        #expect(TaskOrdering.byPriority(items).map(\.title) == ["Urgent", "Early", "Late", "Dated", "A", "B"])
    }
}

@Suite("StepMove")
struct StepMoveTests {
    @Test func targetsStayInsideTheList() {
        #expect(StepMove.targetIndex(from: 0, direction: .upward, count: 3) == nil)
        #expect(StepMove.targetIndex(from: 1, direction: .upward, count: 3) == 0)
        #expect(StepMove.targetIndex(from: 1, direction: .downward, count: 3) == 2)
        #expect(StepMove.targetIndex(from: 2, direction: .downward, count: 3) == nil)
        #expect(StepMove.targetIndex(from: 5, direction: .upward, count: 3) == nil)
    }

    @Test("onMove destinations count positions before the removal")
    func onMoveDestinations() {
        #expect(StepMove.onMoveDestination(from: 1, direction: .upward, count: 3) == 0)
        #expect(StepMove.onMoveDestination(from: 1, direction: .downward, count: 3) == 3)
        let moved = OrderedMove.move(["a", "b", "c"], fromOffsets: [1], toOffset: 3)
        #expect(moved == ["a", "c", "b"])
    }
}

@Suite("Possible blockers")
struct PossibleBlockerTests {
    @Test func excludesItselfCurrentBlockersAndCycles() {
        // 2 is blocked by 1, 3 is blocked by 2.
        let blockers: [Int: Set<Int>] = [2: [1], 3: [2]]
        #expect(DependencyGraph.possibleBlockers(for: 2, among: [1, 2, 3, 4], blockers: blockers) == [4])
        #expect(DependencyGraph.possibleBlockers(for: 1, among: [1, 2, 3, 4], blockers: blockers) == [4])
        #expect(DependencyGraph.possibleBlockers(for: 4, among: [1, 2, 3, 4], blockers: blockers) == [1, 2, 3])
    }
}
