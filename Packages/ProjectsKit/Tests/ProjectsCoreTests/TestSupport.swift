import Foundation
@testable import ProjectsCore

/// Fixed calendars so that tests do not depend on the machine's region settings.
enum TestCalendars {
    static var germany: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "de_DE")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static var unitedStates: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }
}

extension Calendar {
    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

struct FakeTask: TaskFilterable {
    var title: String
    var details: String = ""
    var status: TaskStatus = .todo
    var priority: TaskPriority = .medium
    var dueDate: Date?
    var labelIDs: Set<UUID> = []
}
