import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// A Gantt-style overview: one bar per task from its start to its due date.
struct ProjectTimelineView: View {
    enum Zoom: Int, CaseIterable, Identifiable {
        case twoWeeks = 14
        case month = 31
        case quarter = 92

        var id: Int { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .twoWeeks: "2 Weeks"
            case .month: "Month"
            case .quarter: "Quarter"
            }
        }

        var dayWidth: Double {
            switch self {
            case .twoWeeks: 48
            case .month: 28
            case .quarter: 12
            }
        }
    }

    let project: Project
    @State private var zoom = Zoom.month
    @State private var start = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var titleWidth: CGFloat = 120

    private let calendar = Calendar.autoupdatingCurrent

    private var scheduled: [TaskItem] {
        project.taskList
            .filter { $0.dueDate != nil || $0.startDate != nil }
            .sorted { ($0.startDate ?? $0.dueDate ?? .now) < ($1.startDate ?? $1.dueDate ?? .now) }
    }

    var body: some View {
        let layout = TimelineLayout(start: start, dayCount: zoom.rawValue, dayWidth: zoom.dayWidth, calendar: calendar)
        let tasks = scheduled
        let unscheduled = project.taskList.count - tasks.count

        PageScrollView(maxWidth: .infinity) {
            ProjectPageHeader(project: project)
            controls
            if tasks.isEmpty {
                ContentUnavailableView(
                    "Nothing Scheduled",
                    systemImage: "calendar.badge.clock",
                    description: Text("Give tasks a start or due date to see them on the timeline.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                // The page scrolls vertically; only the bars scroll horizontally, so the card is
                // exactly as tall as its rows.
                HStack(alignment: .top, spacing: 0) {
                    titleColumn(tasks)
                    Divider()
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            dayHeader(layout)
                            ForEach(tasks) { task in
                                bar(for: task, layout: layout)
                            }
                        }
                        .overlay(alignment: .topLeading) { todayMarker(layout, rows: tasks.count) }
                    }
                }
                .clipShape(.rect(cornerRadius: TFRadius.large))
                .tfCard(padding: 0)
            }
            if unscheduled > 0 {
                Text("\(unscheduled) tasks without dates are not shown.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TFSpacing.xSmall)
            }
        }
    }

    private var controls: some View {
        HStack {
            Picker("Zoom", selection: $zoom) {
                ForEach(Zoom.allCases) { zoom in
                    Text(zoom.title).tag(zoom)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            Spacer()
            Button {
                shift(by: -zoom.rawValue / 2)
            } label: {
                Label("Earlier", systemImage: "chevron.left")
            }
            Button("Today") {
                start = calendar.date(byAdding: .day, value: -3, to: .now) ?? .now
            }
            Button {
                shift(by: zoom.rawValue / 2)
            } label: {
                Label("Later", systemImage: "chevron.right")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
    }

    private func titleColumn(_ tasks: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: rowHeight)
            ForEach(tasks) { task in
                NavigationLink(value: Route.task(task.id)) {
                    Text(task.title)
                        .font(.subheadline)
                        .lineLimit(1)
                        .frame(width: titleWidth, height: rowHeight, alignment: .leading)
                        .padding(.horizontal, TFSpacing.small)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dayHeader(_ layout: TimelineLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(layout.days, id: \.self) { day in
                VStack(spacing: 0) {
                    if zoom != .quarter || calendar.component(.weekday, from: day) == calendar.firstWeekday {
                        Text(day, format: .dateTime.day())
                            .font(.caption2.weight(calendar.isDateInToday(day) ? .bold : .regular))
                        if zoom == .twoWeeks {
                            Text(day, format: .dateTime.weekday(.narrow))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: layout.dayWidth, height: rowHeight)
                .background(calendar.isDateInWeekend(day) ? TFColor.surfaceSecondary.opacity(0.6) : .clear)
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(for task: TaskItem, layout: TimelineLayout) -> some View {
        let start = task.startDate ?? task.dueDate ?? .now
        let end = task.dueDate ?? task.startDate ?? .now
        let geometry = layout.bar(from: start, to: end)
        return ZStack(alignment: .leading) {
            Color.clear.frame(width: layout.totalWidth, height: rowHeight)
            if let geometry {
                RoundedRectangle(cornerRadius: 6)
                    .fill(task.isCompleted ? Color.secondary.opacity(0.4) : task.status.color.opacity(0.85))
                    .frame(width: max(geometry.width - 4, 6), height: rowHeight - 12)
                    .offset(x: geometry.offset + 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(task.title))
        .accessibilityValue(Text("\(start.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))"))
    }

    @ViewBuilder
    private func todayMarker(_ layout: TimelineLayout, rows: Int) -> some View {
        if let today = layout.bar(from: .now, to: .now) {
            Rectangle()
                .fill(TFColor.danger)
                .frame(width: 2, height: rowHeight * CGFloat(rows + 1))
                .offset(x: today.offset + today.width / 2)
                .accessibilityHidden(true)
        }
    }

    private func shift(by days: Int) {
        start = calendar.date(byAdding: .day, value: days, to: start) ?? start
    }
}
