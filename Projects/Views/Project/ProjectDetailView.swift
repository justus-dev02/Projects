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
    @Environment(\.modelContext) private var modelContext
    
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
    private let dataService: DataService

    init(
        project: Project,
        dataService: DataService? = nil,
        projectRepo: ProjectRepository? = nil,
        taskRepo: TaskRepository? = nil
    ) {
        self.project = project
        self.dataService = dataService ?? DataService.shared
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
    case list = "List"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .board: return "square.grid.2x2.fill"
        case .list: return "list.bullet"
        }
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    @StateObject private var viewModel: ProjectDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init(project: Project) {
        _viewModel = StateObject(wrappedValue: ProjectDetailViewModel(project: project))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            projectToolbar
            
            // Content
            Group {
                switch viewModel.selectedViewType {
                case .board:
                    kanbanBoard
                case .list:
                    taskListView
                }
            }
        }
        .navigationTitle(viewModel.project.name)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TFButton(title: "New Task", style: .primary, size: .small, icon: "plus") {
                    viewModel.showingCreateTask = true
                }
            }
        }
        .task {
            viewModel.loadData()
        }
        .sheet(isPresented: $viewModel.showingCreateTask) {
            CreateTaskView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
    
    // MARK: - Project Toolbar
    private var projectToolbar: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // View Type Picker
            Picker("View", selection: $viewModel.selectedViewType) {
                ForEach(ViewType.allCases) { viewType in
                    SwiftUI.Label(viewType.rawValue, systemImage: viewType.icon)
                        .tag(viewType)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
            
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
    private var kanbanBoard: some View {
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
    private var taskListView: some View {
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
            .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Preview
#Preview("Project Detail") {
    let project = Project(name: "Website Redesign", projectDescription: "Redesign company website", color: "#4ECDC4", icon: "folder.fill")
    NavigationStack {
        ProjectDetailView(project: project)
    }
}

