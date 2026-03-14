//
//  ProjectDetailView.swift
//  Projects
//
//  TaskFlow - Project Detail View with Kanban Board
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Project Detail View Model
@MainActor
class ProjectDetailViewModel: ObservableObject {
    let project: Project
    let modelContext: ModelContext
    let dataService: DataService

    @Published var columns: [BoardColumn] = []
    @Published var tasks: [Task] = []
    @Published var stats: ProjectStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTask: Task?
    @Published var showingCreateTask = false
    @Published var searchText = ""
    @Published var selectedViewType: ViewType = .board

    private let projectRepo: ProjectRepository
    private let taskRepo: TaskRepository

    init(
        project: Project,
        modelContext: ModelContext,
        dataService: DataService? = nil,
        projectRepo: ProjectRepository? = nil,
        taskRepo: TaskRepository? = nil
    ) {
        self.project = project
        self.modelContext = modelContext
        self.dataService = dataService ?? DataService(modelContext: modelContext)
        self.projectRepo = projectRepo ?? ProjectRepository(dataService: self.dataService)
        self.taskRepo = taskRepo ?? TaskRepository(dataService: self.dataService)
    }

    func loadData() {
        isLoading = true

        do {
            columns = try projectRepo.getBoardColumns(for: project)
            tasks = try taskRepo.getTasksForProject(projectId: project.id)
            stats = try projectRepo.getProjectStats(projectId: project.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createTask(title: String, taskDescription: String?, priority: String, dueDate: Date?, columnId: String) throws -> Task {
        guard let column = columns.first(where: { $0.id == columnId }) else {
            throw NSError(domain: "Column not found", code: 404)
        }

        let task = try taskRepo.createTask(
            title: title,
            taskDescription: taskDescription,
            priority: priority,
            dueDate: dueDate,
            column: column,
            project: project
        )

        tasks.append(task)
        return task
    }
    
    func moveTask(_ task: Task, to columnId: String, order: Int) throws {
        guard let column = columns.first(where: { $0.id == columnId }) else {
            throw NSError(domain: "Column not found", code: 404)
        }
        
        try taskRepo.moveTask(task, to: column, order: order)
        
        // Update local state
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].column = column
            tasks[index].order = order
        }
    }
    
    func updateTaskStatus(_ task: Task, status: String) throws {
        try taskRepo.updateTask(task, status: status)
        
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].status = status
        }
    }
    
    func deleteTask(_ task: Task) throws {
        try taskRepo.deleteTask(task)
        tasks.removeAll { $0.id == task.id }
    }
    
    var filteredTasks: [Task] {
        if searchText.isEmpty {
            return tasks
        }
        return tasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.taskDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    func tasksForColumn(_ column: BoardColumn) -> [Task] {
        filteredTasks.filter { $0.column?.id == column.id }
            .sorted { $0.order < $1.order }
    }
}

// MARK: - View Type
enum ViewType: String, CaseIterable, Identifiable {
    case board = "Board"
    case calendar = "Calendar"
    case timeline = "Timeline"
    case list = "List"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .board: return "square.grid.2x2.fill"
        case .calendar: return "calendar"
        case .timeline: return "timeline"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Filter Options
struct TaskFilterOptions {
    var status: Set<String> = []
    var priority: Set<String> = []
    var assigneeId: String?
    var labelId: String?
    var dueDateRange: DateRange?
    var showOverdueOnly: Bool = false
    var showBlockedOnly: Bool = false

    enum DateRange {
        case today
        case thisWeek
        case thisMonth
        case custom(start: Date, end: Date)
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ProjectDetailViewModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let project: Project

    @State private var searchText = ""
    @State private var showingCreateTask = false
    @State private var selectedTask: Task? = nil
    @State private var selectedViewType: ViewType = .board
    @State private var showOverdueOnly: Bool = false
    @State private var showBlockedOnly: Bool = false
    
    // FIXED: Moved selectedStatuses to the correct scope
    @State private var selectedStatuses: Set<String> = []

    var body: some View {
        Group {
            if let vm = viewModel {
                projectContent(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = ProjectDetailViewModel(
                    project: project,
                    modelContext: modelContext
                )
                viewModel?.loadData()
            }
        }
    }

    @ViewBuilder
    private func projectContent(viewModel: ProjectDetailViewModel) -> some View {
        VStack(spacing: 0) {
            // Toolbar
            projectToolbar(viewModel: viewModel)

            // Content
            Group {
                switch selectedViewType {
                case .board:
                    KanbanBoardView(viewModel: viewModel)
                case .calendar:
                    CalendarView(projectId: project.id, dataService: viewModel.dataService)
                case .timeline:
                    TimelineView(projectId: project.id, dataService: viewModel.dataService)
                case .list:
                    // FIXED: Pass selectedStatuses to EnhancedTaskListView
                    EnhancedTaskListView(viewModel: viewModel, selectedStatuses: $selectedStatuses)
                }
            }
        }
        .navigationTitle(viewModel.project.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .searchable(text: $searchText, prompt: "Search tasks")
        .onChange(of: searchText) {
            viewModel.searchText = searchText
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // FIXED: Toolbar menu structure
                Menu {
                    // Filter Menu
                    Menu {
                        Toggle("Overdue Only", isOn: $showOverdueOnly)
                        Toggle("Blocked Only", isOn: $showBlockedOnly)

                        Divider()

                        ForEach(Task.Status.allCases) { status in
                            Toggle(status.rawValue, isOn: statusBinding(for: status))
                        }
                    } label: {
                        SwiftUI.Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    // Templates
                    NavigationLink {
                        TaskTemplatesView(projectId: project.id, dataService: viewModel.dataService)
                    } label: {
                        SwiftUI.Label("Templates", systemImage: "doc.text.badge.plus")
                    }

                    // Custom Fields
                    NavigationLink {
                        CustomFieldsView(projectId: project.id, dataService: viewModel.dataService)
                    } label: {
                        SwiftUI.Label("Custom Fields", systemImage: "text.badge.checkmark")
                    }

                    // Invitations
                    NavigationLink {
                        InvitationView(targetType: .project, targetId: project.id, dataService: viewModel.dataService)
                    } label: {
                        SwiftUI.Label("Team", systemImage: "person.2.fill")
                    }

                    Divider()

                    Button(action: {
                        showingCreateTask = true
                    }) {
                        SwiftUI.Label("New Task", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingCreateTask) {
            CreateTaskView(viewModel: viewModel)
        }
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
    
    // FIXED: Moved statusBinding helper to the correct scope (ProjectDetailView)
    private func statusBinding(for status: Task.Status) -> Binding<Bool> {
        Binding<Bool>(
            get: { selectedStatuses.contains(status.rawValue.lowercased()) },
            set: { isSelected in
                if isSelected {
                    selectedStatuses.insert(status.rawValue.lowercased())
                } else {
                    selectedStatuses.remove(status.rawValue.lowercased())
                }
            }
        )
    }

    // MARK: - Project Toolbar
    private func projectToolbar(viewModel: ProjectDetailViewModel) -> some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // View Type Picker
            Picker("View", selection: $selectedViewType) {
                ForEach(ViewType.allCases) { viewType in
                    SwiftUI.Label(viewType.rawValue, systemImage: viewType.icon)
                        .tag(viewType)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            .onChange(of: selectedViewType) {
                viewModel.selectedViewType = selectedViewType
            }

            Spacer()

            // Project Stats
            if let stats = viewModel.stats {
                HStack(spacing: TaskFlowSpacing.large) {
                    StatBadge(
                        value: "\(stats.totalTasks)",
                        label: "Tasks",
                        icon: "checkmark.seal.fill"
                    )

                    StatBadge(
                        value: "\(stats.completedTasks)",
                        label: "Done",
                        icon: "checkmark.circle.fill"
                    )
                }
            }
        }
        .padding()
        .background(TaskFlowColors.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(TaskFlowColors.border),
            alignment: .bottom
        )
    }

    // MARK: - Kanban Board
    private func kanbanBoard(viewModel: ProjectDetailViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: TaskFlowSpacing.large) {
                ForEach(viewModel.columns, id: \.id) { column in
                    KanbanColumn(
                        column: column,
                        tasks: viewModel.tasksForColumn(column),
                        viewModel: viewModel
                    )
                }
            }
            .padding()
        }
        .background(TaskFlowColors.background)
    }

    // MARK: - Task List View
    private func taskListView(viewModel: ProjectDetailViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: TaskFlowSpacing.small) {
                ForEach(viewModel.filteredTasks.sorted { $0.createdAt > $1.createdAt }, id: \.id) { task in
                    TaskListRow(task: task)
                        .onTapGesture {
                            viewModel.selectedTask = task
                        }
                }
            }
            .padding()
        }
        .background(TaskFlowColors.background)
    }
}

// MARK: - Kanban Column
struct KanbanColumn: View {
    let column: BoardColumn
    let tasks: [Task]
    @ObservedObject var viewModel: ProjectDetailViewModel
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            // Column Header
            HStack {
                Circle()
                    .fill(Color(hex: column.color))
                    .frame(width: 10, height: 10)
                
                Text(column.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(TaskFlowColors.textTertiary)
                    .padding(.horizontal, TaskFlowSpacing.small)
                    .padding(.vertical, 2)
                    .background(TaskFlowColors.background)
                    .cornerRadius(TaskFlowRadius.small)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
            .padding(.horizontal, TaskFlowSpacing.medium)
            .padding(.vertical, TaskFlowSpacing.small)
            
            // Tasks
            if isExpanded {
                LazyVStack(spacing: TaskFlowSpacing.small) {
                    ForEach(tasks, id: \.id) { task in
                        TaskCard(task: task)
                            .onTapGesture {
                                viewModel.selectedTask = task
                            }
                    }
                    
                    // Add Task Button
                    Button(action: {
                        viewModel.showingCreateTask = true
                    }) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("Add Task")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(TaskFlowColors.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TaskFlowSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                                .stroke(TaskFlowColors.border, lineWidth: 1)
                                .background(TaskFlowColors.background)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(width: 300, height: 400)
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.large)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Task Card
struct TaskCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            // Labels
            if let labels = task.labels, !labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(labels.prefix(3), id: \.id) { taskLabel in
                            if let label = taskLabel.label {
                                TFLabelBadge(name: label.name, colorHex: label.color, size: .small)
                            }
                        }
                    }
                }
            }
            
            // Title
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(TaskFlowColors.textPrimary)
                .lineLimit(2)
            
            // Description preview
            if let taskDescription = task.taskDescription {
                Text(taskDescription)
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Footer
            HStack {
                // Priority
                TFPriorityBadge(priority: task.priority, size: .small, style: .outline)
                
                Spacer()
                
                // Due Date
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                }
                
                // Comments & Attachments
                HStack(spacing: TaskFlowSpacing.small) {
                    if task.commentCount > 0 {
                        SwiftUI.Label("\(task.commentCount)", systemImage: "message.fill")
                            .font(.system(size: 10))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                    
                    if task.attachmentCount > 0 {
                        SwiftUI.Label("\(task.attachmentCount)", systemImage: "paperclip")
                            .font(.system(size: 10))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                }
            }
            
            // Subtask Progress
            if task.totalSubtaskCount > 0 {
                TFTaskProgress(
                    completed: task.completedSubtaskCount,
                    total: task.totalSubtaskCount,
                    height: 4
                )
            }
            
            // Assignee
            if let assignee = task.assignee {
                HStack {
                    Spacer()
                    TFAvatar(name: assignee.displayName, colorHex: assignee.avatarColor, size: .xSmall)
                }
            }
        }
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Task List Row
struct TaskListRow: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 20, height: 20)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                HStack(spacing: TaskFlowSpacing.small) {
                    TFPriorityBadge(priority: task.priority, size: .small, style: .outline)
                    
                    if let dueDate = task.dueDate {
                        SwiftUI.Label(formatDueDate(dueDate), systemImage: "calendar")
                            .font(.system(size: 11))
                            .foregroundColor(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            // Labels
            if let labels = task.labels, !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(3), id: \.id) { taskLabel in
                        if let label = taskLabel.label {
                            Circle()
                                .fill(Color(hex: label.color))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }
            
            // Assignee
            if let assignee = task.assignee {
                TFAvatar(name: assignee.displayName, colorHex: assignee.avatarColor, size: .small)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textTertiary)
        }
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        switch task.status.lowercased() {
        case "todo": return TaskFlowColors.statusTodo
        case "inprogress": return TaskFlowColors.statusInProgress
        case "review": return TaskFlowColors.statusReview
        case "done": return TaskFlowColors.statusDone
        default: return TaskFlowColors.statusTodo
        }
    }
    
    private var statusIcon: String {
        switch task.status.lowercased() {
        case "todo": return "circle"
        case "inprogress": return "arrow.triangle.2.circlepath"
        case "review": return "eye.fill"
        case "done": return "checkmark"
        default: return "circle"
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Create Task View
struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProjectDetailViewModel
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPriority = "medium"
    @State private var selectedColumnId: String
    @State private var dueDate: Date?
    @State private var isLoading = false
    
    init(viewModel: ProjectDetailViewModel) {
        self.viewModel = viewModel
        _selectedColumnId = State(initialValue: viewModel.columns.first?.id ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TFTextField(
                        title: "Title",
                        placeholder: "Enter task title",
                        text: $title,
                        errorMessage: title.isEmpty ? "Title is required" : nil
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
                
                Section {
                    TFTextField(
                        title: "Description",
                        placeholder: "Enter task description",
                        text: $description,
                        multiline: true,
                        minLineCount: 4
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
                
                Section {
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Task.Priority.allCases) { priority in
                            Text(priority.rawValue).tag(priority.rawValue)
                        }
                    }
                }
                
                Section {
                    Picker("Column", selection: $selectedColumnId) {
                        ForEach(viewModel.columns, id: \.id) { column in
                            Text(column.name).tag(column.id)
                        }
                    }
                }
                
                Section {
                    TFDatePicker(
                        title: "Due Date",
                        date: $dueDate,
                        hintText: "Optional - When should this be done?"
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
            }
            .navigationTitle("New Task")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    TFButton(
                        title: "Create",
                        style: .primary,
                        size: .small,
                        isLoading: isLoading
                    ) {
                        createTask()
                    }
                }
            }
        }
    }
    
    private func createTask() {
        guard !title.isEmpty else { return }

        isLoading = true

        do {
            _ = try viewModel.createTask(
                title: title,
                taskDescription: description.isEmpty ? nil : description,
                priority: selectedPriority,
                dueDate: dueDate,
                columnId: selectedColumnId
            )

            dismiss()
        } catch {
            print("Error creating task: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Enhanced Task List View
struct EnhancedTaskListView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    
    // FIXED: Receive selectedStatuses as a Binding
    @Binding var selectedStatuses: Set<String>
    
    @State private var sortBy: SortOption = .dueDate
    @State private var sortOrder: SortOrder = .ascending
    @State private var selectedTask: Task?
    @State private var bulkSelectionState = BulkSelectionState()

    enum SortOption: String, CaseIterable, Identifiable {
        case dueDate = "Due Date"
        case priority = "Priority"
        case createdAt = "Created"
        case title = "Title"
        case status = "Status"

        var id: String { rawValue }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case ascending = "Ascending"
        case descending = "Descending"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TaskFlowSpacing.small) {
                // Sort Bar
                sortBar

                // Bulk Actions (if selection active)
                if bulkSelectionState.showBulkActions {
                    bulkActionsBar
                }

                // Task List
                LazyVStack(spacing: TaskFlowSpacing.small) {
                    ForEach(sortedTasks, id: \.id) { task in
                        EnhancedTaskListRow(
                            task: task,
                            isSelected: bulkSelectionState.selectedTaskIds.contains(task.id),
                            isSelectionMode: bulkSelectionState.isSelectionMode,
                            onTap: {
                                if bulkSelectionState.isSelectionMode {
                                    bulkSelectionState.toggleSelection(for: task.id)
                                } else {
                                    selectedTask = task
                                }
                            },
                            onLongPress: {
                                bulkSelectionState.isSelectionMode = true
                                bulkSelectionState.toggleSelection(for: task.id)
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .background(TaskFlowColors.background)
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }

    private var sortBar: some View {
        HStack {
            // Sort Picker
            Menu {
                ForEach(SortOption.allCases) { option in
                    Button {
                        sortBy = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                ForEach(SortOrder.allCases) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                    Text("\(sortBy.rawValue) (\(sortOrder.rawValue.prefix(1).uppercased()))")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(TaskFlowColors.textPrimary)
                .padding(.horizontal, TaskFlowSpacing.medium)
                .padding(.vertical, TaskFlowSpacing.small)
                .background(TaskFlowColors.surface)
                .cornerRadius(TaskFlowRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: TaskFlowRadius.small)
                        .stroke(TaskFlowColors.border, lineWidth: 1)
                )
            }

            Spacer()

            // Selection Mode Toggle
            Button(action: {
                bulkSelectionState.toggleSelectionMode()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: bulkSelectionState.isSelectionMode ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundColor(bulkSelectionState.isSelectionMode ? TaskFlowColors.primary : TaskFlowColors.textSecondary)
                    Text("Select")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(bulkSelectionState.isSelectionMode ? TaskFlowColors.primary : TaskFlowColors.textSecondary)
                }
            }
        }
        .padding(.vertical, TaskFlowSpacing.small)
    }

    private var bulkActionsBar: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Text("\(bulkSelectionState.selectedCount) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(TaskFlowColors.textPrimary)

            Spacer()

            Button(action: {
                bulkSelectionState.deselectAll()
            }) {
                Text("Cancel")
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textSecondary)
            }

            Button(action: {
                // Delete selected
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(TaskFlowColors.error)
            }

            Button(action: {
                // Move selected
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(TaskFlowColors.primary)
            }
        }
        .padding(.horizontal, TaskFlowSpacing.medium)
        .padding(.vertical, TaskFlowSpacing.small)
        .background(TaskFlowColors.primary.opacity(0.1))
        .cornerRadius(TaskFlowRadius.small)
    }

    private var sortedTasks: [Task] {
        var tasks = viewModel.filteredTasks

        // Apply filters
        if !selectedStatuses.isEmpty {
            tasks = tasks.filter { selectedStatuses.contains($0.status.lowercased()) }
        }

        // Sort
        tasks.sort { task1, task2 in
            switch sortBy {
            case .dueDate:
                let date1 = task1.dueDate ?? .distantFuture
                let date2 = task2.dueDate ?? .distantFuture
                return sortOrder == .ascending ? date1 < date2 : date1 > date2
            case .priority:
                let p1 = Task.Priority(rawValue: task1.priority)?.weight ?? 2
                let p2 = Task.Priority(rawValue: task2.priority)?.weight ?? 2
                return sortOrder == .ascending ? p1 < p2 : p1 > p2
            case .createdAt:
                return sortOrder == .ascending ? task1.createdAt < task2.createdAt : task1.createdAt > task2.createdAt
            case .title:
                return sortOrder == .ascending ? task1.title < task2.title : task1.title > task2.title
            case .status:
                return sortOrder == .ascending ? task1.status < task2.status : task1.status > task2.status
            }
        }

        return tasks
    }
}

// MARK: - Enhanced Task List Row
struct EnhancedTaskListRow: View {
    let task: Task
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Selection Checkbox
            if isSelectionMode {
                Button(action: onTap) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? TaskFlowColors.primary : TaskFlowColors.textTertiary)
                }
            }

            // Status Indicator
            ZStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 20, height: 20)

                Image(systemName: statusIcon)
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: TaskFlowSpacing.small) {
                    TFPriorityBadge(priority: task.priority, size: .small, style: .outline)

                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                    }

                    // Dependency indicator
                    if task.isBlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(TaskFlowColors.warning)
                    }
                }
            }

            Spacer()

            // Labels
            if let labels = task.labels, !labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(labels.prefix(3), id: \.id) { taskLabel in
                        if let label = taskLabel.label {
                            Circle()
                                .fill(Color(hex: label.color))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
            }

            // Assignee
            if let assignee = task.assignee {
                TFAvatar(name: assignee.displayName, colorHex: assignee.avatarColor, size: .small)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textTertiary)
        }
        .padding(TaskFlowSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .fill(isSelected ? TaskFlowColors.primary.opacity(0.1) : TaskFlowColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(isSelected ? TaskFlowColors.primary : TaskFlowColors.border, lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }

    private var statusColor: Color {
        switch task.status.lowercased() {
        case "todo": return TaskFlowColors.statusTodo
        case "inprogress": return TaskFlowColors.statusInProgress
        case "review": return TaskFlowColors.statusReview
        case "done": return TaskFlowColors.statusDone
        default: return TaskFlowColors.statusTodo
        }
    }

    private var statusIcon: String {
        switch task.status.lowercased() {
        case "todo": return "circle"
        case "inprogress": return "arrow.triangle.2.circlepath"
        case "review": return "eye.fill"
        case "done": return "checkmark"
        default: return "circle"
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview("Project Detail") {
    let project = Project(name: "Website Redesign", projectDescription: "Redesign company website", color: "#4ECDC4", icon: "folder.fill")
    return NavigationStack {
        ProjectDetailView(project: project)
    }
}
