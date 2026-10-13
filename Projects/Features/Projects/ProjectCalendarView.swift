import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// A month grid with the tasks due on each day. Respects the user's first weekday.
struct ProjectCalendarView: View {
    let project: Project
    @State private var month = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 52

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        let days = CalendarGrid.days(forMonthContaining: month, today: .now, calendar: calendar)
        let tasksByDay = Dictionary(grouping: project.taskList.filter { $0.dueDate != nil }) {
            calendar.startOfDay(for: $0.dueDate ?? .now)
        }

        PageScrollView {
                ProjectPageHeader(project: project)
                monthHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(Array(CalendarGrid.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    ForEach(days) { day in
                        dayCell(day, tasks: tasksByDay[calendar.startOfDay(for: day.date)] ?? [])
                    }
                }
                .tfCard(padding: TFSpacing.small)

                selectedDayTasks(tasksByDay[selectedDay] ?? [])
        }
    }

    private var monthHeader: some View {
        HStack {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                shiftMonth(by: -1)
            } label: {
                Label("Previous Month", systemImage: "chevron.left")
            }
            Button("Today") {
                month = .now
                selectedDay = calendar.startOfDay(for: .now)
            }
            Button {
                shiftMonth(by: 1)
            } label: {
                Label("Next Month", systemImage: "chevron.right")
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
    }

    private func dayCell(_ day: CalendarDay, tasks: [TaskItem]) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDay)
        let openCount = tasks.count { !$0.isCompleted }
        return Button {
            selectedDay = calendar.startOfDay(for: day.date)
        } label: {
            VStack(spacing: TFSpacing.xxSmall) {
                Text(day.date, format: .dateTime.day())
                    .font(.callout.weight(day.isToday ? .bold : .regular))
                    .foregroundStyle(day.isToday ? AnyShapeStyle(TFColor.accent) : day.isInDisplayedMonth ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                HStack(spacing: 2) {
                    ForEach(tasks.prefix(3)) { task in
                        Circle()
                            .fill(task.isCompleted ? Color.secondary : task.priority.color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .background(isSelected ? TFColor.accent.opacity(0.15) : .clear, in: .rect(cornerRadius: TFRadius.small))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day.date, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(Text("\(openCount) open tasks"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectedDayTasks(_ tasks: [TaskItem]) -> some View {
        let sorted = tasks.sorted { ($0.dueDate ?? .now) < ($1.dueDate ?? .now) }
        return CardSection(
            title: Text(selectedDay, format: .dateTime.weekday(.wide).day().month(.wide)),
            subtitle: Text("\(tasks.count) tasks")
        ) {
            if sorted.isEmpty {
                Text("No tasks due on this day.")
                    .foregroundStyle(.secondary)
                    .cardRow()
            } else {
                ForEach(sorted) { task in
                    NavigationLink(value: Route.task(task.id)) {
                        TaskRow(task: task, showsProject: false)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { TaskContextMenu(task: task) }
                    if task.id != sorted.last?.id {
                        CardDivider()
                    }
                }
            }
        }
    }

    private func shiftMonth(by value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: month) ?? month
    }
}
