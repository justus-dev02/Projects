import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Every task across all projects, with search, filters, sorting, paging and bulk actions.
struct AllTasksView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.undoManager) private var undoManager
    @AppStorage("tasks.sort") private var sort = TaskSortOption.dueDate
    @State private var filter = TaskFilter(includeCompleted: false)
    @State private var pageSize = Self.pageSize
    @State private var showsFilters = false
    @State private var selection = Set<UUID>()
    @State private var isSelecting = false
    @FocusState private var isSearchFocused: Bool

    static let pageSize = 100

    var body: some View {
        TaskListContent(
            filter: $filter,
            sort: sort,
            limit: pageSize,
            selection: $selection,
            isSelecting: isSelecting,
            onLoadMore: { pageSize += Self.pageSize }
        )
        .navigationTitle("Tasks")
        .searchable(text: $filter.searchText, prompt: Text("Search tasks"))
        .searchFocused($isSearchFocused)
        .onChange(of: filter) { pageSize = Self.pageSize }
        .onChange(of: dependencies.router.searchFocusRequest) { isSearchFocused = true }
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) {
            if !selection.isEmpty {
                BulkActionBar(selection: $selection)
            }
        }
        .sheet(isPresented: $showsFilters) {
            TaskFilterSheet(filter: $filter)
        }
    }

    private var selectButton: some View {
        Button(isSelecting ? "Done" : "Select") {
            isSelecting.toggle()
            if !isSelecting { selection.removeAll() }
        }
        .accessibilityIdentifier("tasks.select")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                dependencies.router.present(.newTask(projectID: nil))
            } label: {
                Label("New Task", systemImage: "plus")
            }
            .accessibilityIdentifier("tasks.new")
        }
        ToolbarItem {
            Button {
                showsFilters = true
            } label: {
                Label(
                    filter.activeCriteriaCount == 0 ? "Filter" : "Filter (\(filter.activeCriteriaCount))",
                    systemImage: filter.activeCriteriaCount == 0
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
            }
            .accessibilityIdentifier("tasks.filter")
        }
        ToolbarItem {
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(TaskSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
        #if os(iOS)
        // The Mac table selects with ⌘- and ⇧-click, so the button is iOS only.
        ToolbarItem(placement: .topBarLeading) {
            selectButton
        }
        #endif
    }
}

/// The page with the tasks. A separate view so the `@Query` is rebuilt whenever filter, sort or
/// page size change.
///
/// Laid out like "Today": a header sentence, statistic tiles that double as quick filters, and
/// the tasks in a card. Wide pages show the tasks in aligned columns.
private struct TaskListContent: View {
    @Environment(AppDependencies.self) private var dependencies
    @Query private var tasks: [TaskItem]
    @State private var isWide = false
    @State private var summary = DashboardSummary.empty
    @Binding var filter: TaskFilter
    @Binding var selection: Set<UUID>
    let isSelecting: Bool
    let sort: TaskSortOption
    let limit: Int
    let onLoadMore: () -> Void

    init(filter: Binding<TaskFilter>, sort: TaskSortOption, limit: Int, selection: Binding<Set<UUID>>, isSelecting: Bool, onLoadMore: @escaping () -> Void) {
        _filter = filter
        self.sort = sort
        self.limit = limit
        self.isSelecting = isSelecting
        self.onLoadMore = onLoadMore
        _selection = selection
        // One extra element tells whether another page exists.
        _tasks = Query(TaskQueries.descriptor(filter: filter.wrappedValue, sort: sort, now: .now, calendar: .current, limit: limit + 1))
    }

    private var visibleTasks: [TaskItem] {
        let page = TaskQueries.finalize(Array(tasks.prefix(limit)), sort: sort)
        guard !filter.labelIDs.isEmpty else { return page }
        return page.filter { filter.matches($0, now: .now, calendar: .current) }
    }

    var body: some View {
        #if os(macOS)
        macBody(visibleTasks)
        #else
        pageBody(visibleTasks)
        #endif
    }

    /// iPhone and iPad: the card page like "Today".
    private func pageBody(_ visible: [TaskItem]) -> some View {
        PageScrollView(maxWidth: 1100) {
            PageHeader(eyebrow: eyebrow, title: headline)
            quickFilters
            if visible.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                taskCard(visible)
            }
        }
        .accessibilityIdentifier("tasks.list")
        .task(id: dependencies.dataVersion) {
            reloadSummary()
        }
    }

    private func reloadSummary() {
        summary = dependencies.errors.attempt { try dependencies.dashboard.summary() } ?? .empty
    }

    #if os(macOS)
    /// The Mac: a native table below the header. Arrow keys move the selection, ⌘- and ⇧-click
    /// select several tasks (the bulk action bar appears), Return or a double click opens a task,
    /// and the Delete key deletes the selection with undo.
    private func macBody(_ visible: [TaskItem]) -> some View {
        VStack(alignment: .leading, spacing: TFSpacing.large) {
            PageHeader(eyebrow: eyebrow, title: headline)
            quickFilters
            if visible.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MacTaskTable(tasks: visible, selection: $selection)
                    .tfCard(padding: 0)
                if tasks.count > limit {
                    Button("Load More") { onLoadMore() }
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("tasks.loadMore")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TFColor.background)
        .accessibilityIdentifier("tasks.list")
        .task(id: dependencies.dataVersion) {
            reloadSummary()
        }
    }
    #endif

    // MARK: Header

    private var eyebrow: Text {
        let count = filter.refinementCount
        return count == 0 ? Text("All projects") : Text("\(count) filters active")
    }

    private var headline: Text {
        summary.openTasks == 0 ? Text("You're all caught up.") : Text("\(summary.openTasks) open tasks")
    }

    /// Tiles with live numbers. Tapping one filters the list; tapping it again clears the filter.
    private var quickFilters: some View {
        StatTileGrid {
            quickFilterTile(.open, title: "Open", value: summary.openTasks, systemImage: "circle", tint: TFColor.accent)
            quickFilterTile(.dueToday, title: "Due today", value: summary.dueToday, systemImage: "sun.max", tint: .orange)
            quickFilterTile(.overdue, title: "Overdue", value: summary.overdue, systemImage: "exclamationmark.circle", tint: TFColor.danger)
            quickFilterTile(.inProgress, title: "In Progress", value: summary.inProgress, systemImage: "circle.lefthalf.filled", tint: .blue)
        }
    }

    private func quickFilterTile(
        _ quickFilter: QuickFilter,
        title: LocalizedStringKey,
        value: Int,
        systemImage: String,
        tint: Color
    ) -> some View {
        FilterStatTile(
            title: title, value: value, systemImage: systemImage, tint: tint,
            isSelected: quickFilter.isActive(in: filter)
        ) {
            filter = quickFilter.toggled(in: filter)
        }
    }

    // MARK: Tasks

    private func taskCard(_ visible: [TaskItem]) -> some View {
        CardSection(
            title: Text("\(visible.count) tasks"),
            subtitle: Text("Sort order: \(sort.title)")
        ) {
            if isWide {
                TaskColumnsHeader()
                    .padding(.leading, isSelecting ? TaskColumn.completionButton + TFSpacing.medium : 0)
                    .padding(.bottom, TFSpacing.small)
                Divider()
            }
            LazyCardRows(data: visible) { task in
                row(for: task)
            }
            if tasks.count > limit {
                CardDivider()
                Button("Load More") { onLoadMore() }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TFSpacing.small)
                    .accessibilityIdentifier("tasks.loadMore")
            }
        }
        // Measured on the card, so the columns appear exactly when the card is wide enough.
        .adaptiveTaskRows($isWide)
    }

    @ViewBuilder
    private func row(for task: TaskItem) -> some View {
        Group {
            if isSelecting {
                let isSelected = selection.contains(task.id)
                Button {
                    if isSelected { selection.remove(task.id) } else { selection.insert(task.id) }
                } label: {
                    HStack(spacing: TFSpacing.medium) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? TFColor.accent : .secondary)
                            .frame(width: TaskColumn.completionButton)
                            .accessibilityHidden(true)
                        TaskRow(task: task)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            } else {
                NavigationLink(value: Route.task(task.id)) {
                    TaskRow(task: task)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            TaskContextMenu(task: task)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !filter.trimmedSearchText.isEmpty {
            ContentUnavailableView.search(text: filter.trimmedSearchText)
        } else if !filter.isDefault {
            ContentUnavailableView("No Matching Tasks", systemImage: "line.3.horizontal.decrease.circle", description: Text("Change or reset the filters."))
        } else {
            ContentUnavailableView("No Open Tasks", systemImage: "checkmark.circle", description: Text("Tasks from all projects appear here."))
        }
    }
}

#if os(macOS)
/// The task list as a native macOS table.
private struct MacTaskTable: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.undoManager) private var undoManager
    let tasks: [TaskItem]
    @Binding var selection: Set<UUID>
    /// The table takes keyboard focus when it appears, so arrow keys work without a click first.
    @FocusState private var isFocused: Bool

    var body: some View {
        Table(tasks, selection: $selection) {
            TableColumn("Task") { task in
                HStack(spacing: TFSpacing.small) {
                    CompletionButton(task: task)
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                }
            }
            .width(min: 200, ideal: 260)
            TableColumn("Project") { task in
                if let project = task.project {
                    Label(project.name, systemImage: project.symbolName)
                        .labelStyle(.tfCompact)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .width(min: 90, ideal: 130)
            TableColumn("People") { task in
                PeopleBadge(names: task.involvedPeople, maxVisible: 3)
            }
            .width(min: 60, ideal: 90)
            TableColumn("Due") { task in
                if let dueDate = task.dueDate {
                    DueDateLabel(date: dueDate, isCompleted: task.isCompleted)
                }
            }
            .width(min: 80, ideal: 100)
            TableColumn("Priority") { task in
                PriorityBadge(task.priority)
            }
            .width(min: 80, ideal: 100)
            TableColumn("Notes") { task in
                HStack(spacing: TFSpacing.small) {
                    BlockedBadge(task: task, showsText: false)
                    QuestionsBadge(openCount: task.openQuestionCount)
                }
            }
            .width(min: 50, ideal: 70)
            TableColumn(Text(verbatim: "")) { task in
                CommentDot(task: task)
            }
            .width(16)
        }
        .scrollContentBackground(.hidden)
        .clipShape(.rect(cornerRadius: TFRadius.large))
        .accessibilityIdentifier("tasks.list")
        .contextMenu(forSelectionType: UUID.self) { ids in
            if ids.count == 1, let task = ids.first.flatMap({ try? dependencies.tasks.task(id: $0) }) {
                TaskContextMenu(task: task)
            } else if !ids.isEmpty {
                Button(role: .destructive) {
                    deleteTasks(with: ids)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } primaryAction: { ids in
            if let id = ids.first {
                dependencies.router.push(.task(id))
            }
        }
        .onDeleteCommand {
            deleteTasks(with: selection)
        }
        .focused($isFocused)
        .onAppear { isFocused = true }
    }

    private func deleteTasks(with ids: Set<UUID>) {
        let tasks = ids.compactMap { try? dependencies.tasks.task(id: $0) }
        selection.subtract(ids)
        dependencies.delete(tasks, undoManager: undoManager)
    }
}
#endif

/// Actions for a single task, shared by lists and the board.
struct TaskContextMenu: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.undoManager) private var undoManager
    let task: TaskItem

    var body: some View {
        Button {
            dependencies.errors.perform { try dependencies.tasks.toggleCompletion(task) }
        } label: {
            Label(task.isCompleted ? "Mark as Open" : "Mark as Done", systemImage: task.isCompleted ? "circle" : "checkmark.circle")
        }
        .disabled(!task.isCompleted && !task.canChangeStatus(to: .done))
        Menu {
            ForEach(TaskStatus.allCases) { status in
                Button(status.title) {
                    dependencies.errors.perform { try dependencies.tasks.setStatus(task, to: status) }
                }
                .disabled(task.status == status || !task.canChangeStatus(to: status))
            }
            if task.isBlocked, !task.isCompleted {
                Divider()
                Text("Waiting for \(task.openBlockers.map(\.title).formatted(.list(type: .and)))")
            }
        } label: {
            Label("Status", systemImage: "circle.dashed")
        }
        Menu {
            ForEach(TaskPriority.allCases.reversed()) { priority in
                Button(priority.title) {
                    dependencies.errors.perform { try dependencies.tasks.setPriority([task], to: priority) }
                }
                .disabled(task.priority == priority)
            }
        } label: {
            Label("Priority", systemImage: "flag")
        }
        Button {
            dependencies.router.present(.editTask(task.id))
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button {
            dependencies.errors.perform { try dependencies.tasks.duplicate(task) }
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        ShareLink(item: task.deepLink.url, subject: Text(task.title)) {
            Label("Share Link", systemImage: "link")
        }
        Divider()
        Button(role: .destructive) {
            dependencies.delete([task], undoManager: undoManager)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .accessibilityIdentifier("task.delete")
    }
}

/// Actions for several selected tasks.
private struct BulkActionBar: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.undoManager) private var undoManager
    @Binding var selection: Set<UUID>

    var body: some View {
        HStack(spacing: TFSpacing.large) {
            Text("\(selection.count) selected")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Spacer()
            Button {
                apply { try dependencies.tasks.setStatus($0, to: .done) }
            } label: {
                Label("Mark as Done", systemImage: "checkmark.circle")
            }
            Menu {
                ForEach(TaskPriority.allCases.reversed()) { priority in
                    Button(priority.title) {
                        apply { try dependencies.tasks.setPriority($0, to: priority) }
                    }
                }
            } label: {
                Label("Priority", systemImage: "flag")
            }
            Menu {
                Button("Today") { setDue(dayOffset: 0) }
                Button("Tomorrow") { setDue(dayOffset: 1) }
                Button("Next Week") { setDue(dayOffset: 7) }
                Divider()
                Button("Remove Due Date") {
                    apply { try dependencies.tasks.setDueDate($0, to: nil) }
                }
            } label: {
                Label("Due Date", systemImage: "calendar")
            }
            Button(role: .destructive) {
                let tasks = selectedTasks()
                selection.removeAll()
                dependencies.delete(tasks, undoManager: undoManager)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("bulk.delete")
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .padding(.horizontal, TFSpacing.large)
        .padding(.vertical, TFSpacing.medium)
        .glassEffect(.regular, in: .capsule)
        .padding()
    }

    private func selectedTasks() -> [TaskItem] {
        selection.compactMap { try? dependencies.tasks.task(id: $0) }
    }

    private func apply(_ action: ([TaskItem]) throws -> Void) {
        let tasks = selectedTasks()
        dependencies.errors.perform { try action(tasks) }
    }

    private func setDue(dayOffset: Int) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let day = calendar.date(byAdding: .day, value: dayOffset, to: start) ?? start
        let due = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? day
        apply { try dependencies.tasks.setDueDate($0, to: due) }
    }
}
