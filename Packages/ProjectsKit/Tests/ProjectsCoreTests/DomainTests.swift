import Foundation
import Testing
@testable import ProjectsCore

@Suite("Domain enums")
struct DomainTests {
    @Test("Raw values are stable because they are persisted")
    func persistedRawValues() {
        #expect(TaskStatus.allCases.map(\.rawValue) == ["todo", "inProgress", "review", "done"])
        #expect(TaskPriority.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(ProjectStatus.allCases.map(\.rawValue) == ["active", "onHold", "completed"])
        #expect(CustomFieldType.allCases.map(\.rawValue) == ["text", "number", "date", "checkbox", "choice", "url"])
    }

    @Test func onlyDoneIsCompleted() {
        #expect(TaskStatus.allCases.filter(\.isCompleted) == [.done])
    }

    @Test func prioritiesAreOrderedByUrgency() {
        #expect(TaskPriority.allCases.sorted() == [.low, .medium, .high, .urgent])
        #expect(TaskPriority.urgent > .high)
    }

    @Test("Every case has a non-empty title and symbol")
    func titlesAndSymbols() {
        for status in TaskStatus.allCases {
            #expect(!status.title.isEmpty)
            #expect(!status.symbolName.isEmpty)
        }
        for priority in TaskPriority.allCases {
            #expect(!priority.title.isEmpty)
        }
        for category in TemplateCategory.allCases {
            #expect(!category.title.isEmpty)
        }
        for type in CustomFieldType.allCases {
            #expect(!type.title.isEmpty)
        }
    }

    @Test func activityMessagesResolveRawDetails() {
        #expect(ActivityKind.statusChanged.message(detail: "done").contains(TaskStatus.done.title))
        #expect(ActivityKind.priorityChanged.message(detail: "3").contains(TaskPriority.urgent.title))
        #expect(ActivityKind.moved.message(detail: "Backlog").contains("Backlog"))
        #expect(ActivityKind.statusChanged.message(detail: "garbage").contains("–"))
        #expect(ActivityKind.dueDateChanged.message(detail: nil) == ActivityKind.dueDateChanged.message(detail: "not a date"))
    }
}
