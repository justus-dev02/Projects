import Foundation
import Testing
@testable import ProjectsCore

@Suite("TaskFilter")
struct TaskFilterTests {
    let calendar = TestCalendars.germany
    var now: Date { calendar.date(2026, 3, 14, 15) }

    @Test func defaultFilterMatchesEverything() {
        let tasks = [
            FakeTask(title: "A"),
            FakeTask(title: "B", status: .done),
            FakeTask(title: "C", dueDate: calendar.date(2020, 1, 1)),
        ]
        #expect(tasks.allSatisfy { TaskFilter.all.matches($0, now: now, calendar: calendar) })
        #expect(TaskFilter.all.isDefault)
        #expect(TaskFilter.all.activeCriteriaCount == 0)
    }

    @Test func searchIsCaseAndDiacriticInsensitiveAndCoversDetails() {
        let filter = TaskFilter(searchText: "  uber ")
        #expect(filter.matches(FakeTask(title: "Über die Brücke"), now: now, calendar: calendar))
        #expect(filter.matches(FakeTask(title: "x", details: "Ubersicht erstellen"), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "Andere Aufgabe"), now: now, calendar: calendar))
        #expect(filter.isDefault, "Search text alone does not count as a filter criterion")
    }

    @Test func statusAndPriority() {
        let filter = TaskFilter(statuses: [.inProgress, .review], priorities: [.urgent])
        #expect(filter.matches(FakeTask(title: "a", status: .review, priority: .urgent), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "b", status: .todo, priority: .urgent), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "c", status: .review, priority: .high), now: now, calendar: calendar))
        #expect(filter.activeCriteriaCount == 2)
    }

    @Test func excludeCompleted() {
        let filter = TaskFilter(includeCompleted: false)
        #expect(!filter.matches(FakeTask(title: "a", status: .done), now: now, calendar: calendar))
        #expect(filter.matches(FakeTask(title: "b", status: .review), now: now, calendar: calendar))
    }

    @Test func labelsMatchAnyOfTheSelected() {
        let bug = UUID(), feature = UUID(), other = UUID()
        let filter = TaskFilter(labelIDs: [bug, feature])
        #expect(filter.matches(FakeTask(title: "a", labelIDs: [feature, other]), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "b", labelIDs: [other]), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "c"), now: now, calendar: calendar))
    }

    @Test func dueToday() {
        let filter = TaskFilter(due: .today)
        #expect(filter.matches(FakeTask(title: "morning", dueDate: calendar.date(2026, 3, 14, 0, 0)), now: now, calendar: calendar))
        #expect(filter.matches(FakeTask(title: "late", dueDate: calendar.date(2026, 3, 14, 23, 59)), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "tomorrow", dueDate: calendar.date(2026, 3, 15, 0, 0)), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "none"), now: now, calendar: calendar))
    }

    @Test("Overdue excludes completed tasks and tasks due later today")
    func overdue() {
        let filter = TaskFilter(due: .overdue)
        #expect(filter.matches(FakeTask(title: "a", dueDate: calendar.date(2026, 3, 14, 9)), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "b", dueDate: calendar.date(2026, 3, 14, 18)), now: now, calendar: calendar))
        #expect(!filter.matches(FakeTask(title: "c", status: .done, dueDate: calendar.date(2026, 3, 1)), now: now, calendar: calendar))
    }

    @Test func next7DaysAndNoDueDate() {
        let next7 = TaskFilter(due: .next7Days)
        #expect(next7.matches(FakeTask(title: "a", dueDate: calendar.date(2026, 3, 20, 23)), now: now, calendar: calendar))
        #expect(!next7.matches(FakeTask(title: "b", dueDate: calendar.date(2026, 3, 21, 0, 0)), now: now, calendar: calendar))
        let none = TaskFilter(due: .noDueDate)
        #expect(none.matches(FakeTask(title: "c"), now: now, calendar: calendar))
        #expect(!none.matches(FakeTask(title: "d", dueDate: now), now: now, calendar: calendar))
    }

    @Test func dateRanges() {
        #expect(DueFilter.any.dateRange(now: now, calendar: calendar) == nil)
        #expect(DueFilter.noDueDate.dateRange(now: now, calendar: calendar) == nil)
        let today = DueFilter.today.dateRange(now: now, calendar: calendar)
        #expect(today?.lowerBound == calendar.date(2026, 3, 14, 0, 0))
        #expect(today?.upperBound == calendar.date(2026, 3, 15, 0, 0))
    }
}
