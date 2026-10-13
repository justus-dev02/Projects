import AppIntents
import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem
import WidgetKit

/// A value snapshot of a task. Widgets render from values, never from live model objects.
nonisolated struct WidgetTask: Identifiable, Hashable {
    let id: UUID
    let title: String
    let projectName: String
    let dueDate: Date?
    let priority: TaskPriority
    let isCompleted: Bool

    var entity: TaskEntity {
        TaskEntity(id: id, title: title, projectName: projectName, dueDate: dueDate, isCompleted: isCompleted)
    }
}

nonisolated struct TodayEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let overdueCount: Int
    let isPlaceholder: Bool

    static let placeholder = TodayEntry(
        date: .now,
        tasks: [
            WidgetTask(id: UUID(), title: "Plan the week", projectName: "Personal", dueDate: .now, priority: .high, isCompleted: false),
            WidgetTask(id: UUID(), title: "Review pull request", projectName: "App", dueDate: .now, priority: .medium, isCompleted: false),
            WidgetTask(id: UUID(), title: "Book flights", projectName: "Travel", dueDate: .now, priority: .low, isCompleted: false),
        ],
        overdueCount: 1,
        isPlaceholder: true
    )
}

nonisolated struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TodayEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { @MainActor in
            completion(Self.loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TodayEntry>) -> Void) {
        Task { @MainActor in
            let entry = Self.loadEntry()
            // Refresh after midnight so "today" stays correct; the app reloads on every change.
            let calendar = Calendar.current
            let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
            completion(Timeline(entries: [entry], policy: .after(tomorrow)))
        }
    }

    @MainActor
    static func loadEntry() -> TodayEntry {
        do {
            let environment = ServiceEnvironment(context: try SharedStore.container().mainContext)
            let dashboard = DashboardService(environment: environment)
            let summary = try dashboard.summary()
            let tasks = try dashboard.focusTasks(limit: 8).map { task in
                WidgetTask(
                    id: task.id,
                    title: task.title,
                    projectName: task.project?.name ?? "",
                    dueDate: task.dueDate,
                    priority: task.priority,
                    isCompleted: task.isCompleted
                )
            }
            return TodayEntry(date: .now, tasks: tasks, overdueCount: summary.overdue, isPlaceholder: false)
        } catch {
            return TodayEntry(date: .now, tasks: [], overdueCount: 0, isPlaceholder: false)
        }
    }
}

struct TodayTasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedConfiguration.todayWidgetKind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Tasks that are overdue or due today. Tap the circle to complete a task.")
        .supportedFamilies(Self.families)
    }

    private static var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    private var maximumRows: Int {
        switch family {
        case .systemSmall: 3
        case .systemMedium: 3
        case .systemLarge: 8
        default: 2
        }
    }

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            Gauge(value: Double(entry.tasks.count), in: 0...Double(max(entry.tasks.count, 1))) {
                Image(systemName: "checklist")
            } currentValueLabel: {
                Text(entry.tasks.count, format: .number)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetURL(DeepLink.today.url)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("\(entry.tasks.count) due today")
                    .font(.headline)
                if let first = entry.tasks.first {
                    Text(first.title).lineLimit(1)
                }
            }
            .widgetURL(DeepLink.today.url)
        #endif
        default:
            systemView
        }
    }

    private var systemView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                if entry.overdueCount > 0 {
                    Label("\(entry.overdueCount)", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .accessibilityLabel(Text("\(entry.overdueCount) overdue"))
                }
            }
            if entry.tasks.isEmpty {
                Spacer()
                Label("All done for today", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(maximumRows)) { task in
                    row(task)
                }
                Spacer(minLength: 0)
                if entry.tasks.count > maximumRows {
                    Text("+\(entry.tasks.count - maximumRows) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .widgetURL(DeepLink.today.url)
    }

    private func row(_ task: WidgetTask) -> some View {
        HStack(spacing: 6) {
            Button(intent: ToggleTaskCompletionIntent(task: task.entity)) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.priority.color)
            }
            .buttonStyle(.plain)
            .disabled(entry.isPlaceholder)
            Link(destination: DeepLink.task(task.id).url) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(task.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    if family != .systemSmall {
                        Text(task.projectName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
