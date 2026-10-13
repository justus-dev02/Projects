import SwiftUI

/// Shows a due date relative to today ("Today", "Tomorrow", "in 3 days") and highlights
/// overdue dates. Formatting follows the user's language and region.
public struct DueDateLabel: View {
    let date: Date
    let isCompleted: Bool
    let now: Date

    public init(date: Date, isCompleted: Bool, now: Date = .now) {
        self.date = date
        self.isCompleted = isCompleted
        self.now = now
    }

    public var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar")
        }
        .font(.caption)
        .foregroundStyle(isOverdue ? TFColor.danger : .secondary)
        .labelStyle(.tfCompact)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var isOverdue: Bool {
        !isCompleted && date < now
    }

    private var text: String {
        let calendar = Calendar.autoupdatingCurrent
        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "Today", bundle: .module, comment: "Due date")
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "Tomorrow", bundle: .module, comment: "Due date")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday", bundle: .module, comment: "Due date")
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var accessibilityText: Text {
        let formatted = date.formatted(date: .complete, time: .omitted)
        return isOverdue
            ? Text("Overdue since \(formatted)", bundle: .module)
            : Text("Due \(formatted)", bundle: .module)
    }
}
