import Foundation
import Testing
@testable import ProjectsCore

@Suite("CalendarGrid")
struct CalendarGridTests {
    @Test("German calendars start on Monday")
    func germanGrid() {
        let calendar = TestCalendars.germany
        let days = CalendarGrid.days(forMonthContaining: calendar.date(2026, 3, 10), today: calendar.date(2026, 3, 14), calendar: calendar)
        #expect(days.count % 7 == 0)
        // 1 March 2026 is a Sunday, so a Monday-first grid starts on 23 February.
        #expect(days.first?.date == calendar.startOfDay(for: calendar.date(2026, 2, 23)))
        #expect(calendar.component(.weekday, from: days[0].date) == 2)
        #expect(days.filter(\.isInDisplayedMonth).count == 31)
        #expect(days.filter(\.isToday).count == 1)
        #expect(days.first(where: \.isToday)?.date == calendar.startOfDay(for: calendar.date(2026, 3, 14)))
    }

    @Test("US calendars start on Sunday")
    func usGrid() {
        let calendar = TestCalendars.unitedStates
        let days = CalendarGrid.days(forMonthContaining: calendar.date(2026, 3, 10), today: calendar.date(2026, 1, 1), calendar: calendar)
        #expect(days.first?.date == calendar.startOfDay(for: calendar.date(2026, 3, 1)))
        #expect(days.count == 35)
        #expect(days.contains(where: \.isToday) == false)
    }

    @Test func weekdaySymbolsFollowFirstWeekday() {
        #expect(CalendarGrid.weekdaySymbols(calendar: TestCalendars.germany).first == "M")
        #expect(CalendarGrid.weekdaySymbols(calendar: TestCalendars.unitedStates).first == "S")
        #expect(CalendarGrid.weekdaySymbols(calendar: TestCalendars.germany).count == 7)
    }
}

@Suite("TimelineLayout")
struct TimelineLayoutTests {
    let calendar = TestCalendars.germany

    var layout: TimelineLayout {
        TimelineLayout(start: calendar.date(2026, 3, 10, 17), dayCount: 10, dayWidth: 20, calendar: calendar)
    }

    @Test func geometry() {
        #expect(layout.totalWidth == 200)
        #expect(layout.days.count == 10)
        #expect(layout.start == calendar.startOfDay(for: calendar.date(2026, 3, 10)))
    }

    @Test func barInsideRange() throws {
        let bar = try #require(layout.bar(from: calendar.date(2026, 3, 12), to: calendar.date(2026, 3, 14)))
        #expect(bar.offset == 40)
        #expect(bar.width == 60)
    }

    @Test func singleDayBarAndSwappedDates() throws {
        let bar = try #require(layout.bar(from: calendar.date(2026, 3, 11, 23), to: calendar.date(2026, 3, 11, 1)))
        #expect(bar.offset == 20)
        #expect(bar.width == 20)
    }

    @Test func barsAreClippedToTheVisibleRange() throws {
        let bar = try #require(layout.bar(from: calendar.date(2026, 3, 1), to: calendar.date(2026, 3, 30)))
        #expect(bar.offset == 0)
        #expect(bar.width == 200)
    }

    @Test func invisibleBars() {
        #expect(layout.bar(from: calendar.date(2026, 2, 1), to: calendar.date(2026, 3, 9)) == nil)
        #expect(layout.bar(from: calendar.date(2026, 3, 20), to: calendar.date(2026, 3, 25)) == nil)
    }
}
