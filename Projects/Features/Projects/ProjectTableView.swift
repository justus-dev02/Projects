import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// The project's tasks as a table, grouped by status and always sorted by priority (most urgent
/// first, then by due date). A filter above the table shows all statuses or a single one.
///
/// Wide layouts (Mac, iPad) use a real `Table` with columns; narrow ones (iPhone) a grouped list,
/// because a `Table` only shows its first column there.
struct ProjectTableView: View {
    @Environment(AppDependencies.self) private var dependencies
    let project: Project
    /// `nil` shows every status.
    @State private var statusFilter: TaskStatus?
    @State private var selection = Set<UUID>()
    @State private var isWide = false

    /// Tasks per status in workflow order, each sorted by priority.
    private var groups: [(status: TaskStatus, tasks: [TaskItem])] {
        let statuses = statusFilter.map { [$0] } ?? TaskStatus.allCases
        let tasks = project.taskList
        return statuses.map { status in
            (status, TaskOrdering.byPriority(tasks.filter { $0.status == status }))
        }
    }

    var body: some View {
        let groups = groups
        Group {
            if isWide {
                // The table scrolls itself, so the header stays above it and the table sits in a card.
                VStack(alignment: .leading, spacing: TFSpacing.large) {
                    ProjectPageHeader(project: project)
                    filterBar
                    if groups.allSatisfy(\.tasks.isEmpty) {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        table(groups)
                            .scrollContentBackground(.hidden)
                            .padding(TFSpacing.xSmall)
                            .tfCard(padding: 0)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(TFColor.background)
            } else {
                PageScrollView {
                    ProjectPageHeader(project: project)
                    filterBar
                    if groups.allSatisfy(\.tasks.isEmpty) {
                        emptyState
                            .frame(maxWidth: .infinity, minHeight: 280)
                    } else {
                        list(groups)
                    }
                }
            }
        }
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width >= TaskColumn.wideLayoutMinWidth
        } action: { isWide = $0 }
        .accessibilityIdentifier("project.table")
    }

    // MARK: Filter

    /// Chips instead of a segmented control, so "In Progress" and the counts never get truncated.
    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: TFSpacing.small) {
                filterChip(title: String(localized: "All"), count: project.taskList.count, symbol: "square.stack", tint: TFColor.accent, value: nil)
                ForEach(TaskStatus.allCases) { status in
                    filterChip(title: status.title, count: count(of: status), symbol: status.symbolName, tint: status.color, value: status)
                }
            }
            .padding(.vertical, TFSpacing.xxSmall)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityIdentifier("projectTable.filter")
    }

    private func filterChip(title: String, count: Int, symbol: String, tint: Color, value: TaskStatus?) -> some View {
        let isSelected = statusFilter == value
        return Button {
            withAnimation(.snappy) { statusFilter = value }
        } label: {
            HStack(spacing: TFSpacing.xSmall + 2) {
                Image(systemName: symbol)
                    .foregroundStyle(isSelected ? .white : tint)
                Text(title)
                Text(count, format: .number)
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, TFSpacing.medium)
            .padding(.vertical, TFSpacing.small)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(TFColor.surface), in: .capsule)
            .overlay(Capsule().strokeBorder(TFColor.separator.opacity(isSelected ? 0 : 0.5), lineWidth: 0.5))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func count(of status: TaskStatus) -> Int {
        project.taskList.count { $0.status == status }
    }

    // MARK: Wide

    private func table(_ groups: [(status: TaskStatus, tasks: [TaskItem])]) -> some View {
        Table(of: TaskItem.self, selection: $selection) {
            TableColumn("Priority") { task in
                PriorityBadge(task.priority)
            }
            .width(min: 90, ideal: 100, max: 120)
            TableColumn("Task") { task in
                HStack(spacing: TFSpacing.small) {
                    CompletionButton(task: task)
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }
            }
            .width(min: 200, ideal: 320)
            TableColumn("Status") { task in
                StatusBadge(task.status)
            }
            .width(min: 100, ideal: 120, max: 140)
            TableColumn("Due") { task in
                if let dueDate = task.dueDate {
                    DueDateLabel(date: dueDate, isCompleted: task.isCompleted)
                }
            }
            .width(min: 90, ideal: 110, max: 140)
            TableColumn("People") { task in
                PeopleBadge(names: task.involvedPeople, maxVisible: 3)
            }
            .width(min: 70, ideal: 100, max: 160)
            TableColumn("Notes") { task in
                HStack(spacing: TFSpacing.small) {
                    BlockedBadge(task: task)
                    QuestionsBadge(openCount: task.openQuestionCount)
                }
            }
            .width(min: 70, ideal: 110, max: 160)
            TableColumn(Text(verbatim: "")) { task in
                CommentDot(task: task)
            }
            .width(16)
        } rows: {
            ForEach(groups, id: \.status) { group in
                if !group.tasks.isEmpty {
                    Section {
                        ForEach(group.tasks) { task in
                            TableRow(task)
                        }
                    } header: {
                        sectionHeader(group.status, count: group.tasks.count)
                    }
                }
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let id = ids.first, let task = try? dependencies.tasks.task(id: id) {
                TaskContextMenu(task: task)
            }
        } primaryAction: { ids in
            if let id = ids.first {
                dependencies.router.push(.task(id))
            }
        }
    }

    // MARK: Narrow

    /// One card per status, like the sections of "Today".
    @ViewBuilder
    private func list(_ groups: [(status: TaskStatus, tasks: [TaskItem])]) -> some View {
        ForEach(groups, id: \.status) { group in
            if !group.tasks.isEmpty {
                CardSection(title: Text(group.status.title), subtitle: Text("\(group.tasks.count) tasks · sorted by priority")) {
                    Image(systemName: group.status.symbolName)
                        .font(.title3)
                        .foregroundStyle(group.status.color)
                        .accessibilityHidden(true)
                } content: {
                    LazyCardRows(data: group.tasks) { task in
                        NavigationLink(value: Route.task(task.id)) {
                            TaskRow(task: task, showsProject: false)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { TaskContextMenu(task: task) }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ status: TaskStatus, count: Int) -> some View {
        HStack(spacing: TFSpacing.small) {
            Image(systemName: status.symbolName)
                .foregroundStyle(status.color)
                .accessibilityHidden(true)
            Text(status.title)
            Text(count, format: .number)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Text("Sorted by priority")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let statusFilter {
            ContentUnavailableView(
                "No Tasks",
                systemImage: statusFilter.symbolName,
                description: Text("There are no tasks with the status “\(statusFilter.title)”.")
            )
        } else {
            ContentUnavailableView {
                Label("No Tasks Yet", systemImage: "checklist")
            } actions: {
                Button("Add Task") { dependencies.router.present(.newTask(projectID: project.id)) }
                    .buttonStyle(.glassProminent)
            }
        }
    }
}
