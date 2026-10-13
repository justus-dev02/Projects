import Foundation
import Testing
@testable import ProjectsCore

@Suite("RecurrenceRule")
struct RecurrenceRuleTests {
    let calendar = TestCalendars.germany

    @Test(arguments: [
        (RecurrenceRule.Frequency.daily, 1, (2026, 3, 15)),
        (.daily, 3, (2026, 3, 17)),
        (.weekly, 1, (2026, 3, 21)),
        (.weekly, 2, (2026, 3, 28)),
        (.monthly, 1, (2026, 4, 14)),
        (.yearly, 1, (2027, 3, 14)),
    ])
    func nextOccurrence(frequency: RecurrenceRule.Frequency, interval: Int, expected: (Int, Int, Int)) {
        let rule = RecurrenceRule(frequency: frequency, interval: interval)
        let start = calendar.date(2026, 3, 14)
        #expect(rule.nextOccurrence(after: start, calendar: calendar) == calendar.date(expected.0, expected.1, expected.2))
    }

    @Test("Month arithmetic clamps to the last day of shorter months")
    func monthEndClamping() {
        let rule = RecurrenceRule(frequency: .monthly)
        let next = rule.nextOccurrence(after: calendar.date(2026, 1, 31), calendar: calendar)
        #expect(next == calendar.date(2026, 2, 28))
    }

    @Test func stopsAfterEndDate() {
        let rule = RecurrenceRule(frequency: .weekly, endDate: calendar.date(2026, 3, 20))
        #expect(rule.nextOccurrence(after: calendar.date(2026, 3, 14), calendar: calendar) == nil)
        #expect(rule.nextOccurrence(after: calendar.date(2026, 3, 10), calendar: calendar) == calendar.date(2026, 3, 17))
    }

    @Test(arguments: [(-5, 1), (0, 1), (7, 7), (10_000, RecurrenceRule.maximumInterval)])
    func intervalIsClamped(input: Int, expected: Int) {
        #expect(RecurrenceRule(frequency: .daily, interval: input).interval == expected)
    }

    @Test func codableRoundTrip() throws {
        let rule = RecurrenceRule(frequency: .monthly, interval: 2, endDate: calendar.date(2027, 1, 1))
        let data = try JSONEncoder().encode(rule)
        #expect(try JSONDecoder().decode(RecurrenceRule.self, from: data) == rule)
    }

    @Test func descriptionMentionsInterval() {
        #expect(RecurrenceRule(frequency: .weekly, interval: 3).localizedDescription.contains("3"))
    }
}
