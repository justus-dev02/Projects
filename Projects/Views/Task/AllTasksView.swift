//
//  AllTasksView.swift
//  Projects
//
//  TaskFlow - All Tasks View with filtering capabilities
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Task Filter Options
struct TaskFilterOptions: Equatable {
    var status: Set<String> = []
    var priority: Set<String> = []
    var assigneeId: String?
    var labelId: String?
    var dueDateRange: DateRange?
    var showOverdueOnly: Bool = false
    var showBlockedOnly: Bool = false
    var searchText: String = ""

    enum DateRange: Equatable {
        case today
        case thisWeek
        case thisMonth
        case custom(start: Date, end: Date)
    }

    static let empty = TaskFilterOptions()
}

// MARK: - All Tasks View Model
@MainActor
class AllTasksViewModel: ObservableObject {
    @Published var allTasks: [Task] = []
    @Published var filteredTasks: [Task] = []
    @Published var filterOptions: TaskFilterOptions = .empty
    @Published var isShowingFilters = false
    @Published var selectedTask: Task?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var sortBy: TaskSortOption = .dueDate

    private let modelContext: ModelContext
    private let taskRepo: TaskRepository
    private let workspaceId: String?

    init(
        modelContext: ModelContext,
        workspaceId: String? = nil,
        taskRepo: TaskRepository? = nil
    ) {
        self.modelContext = modelContext
        self.workspaceId = workspaceId
        let dataService = DataService(modelContext: modelContext)
        self.taskRepo = taskRepo ?? TaskRepository(dataService: dataService)
    }

    func loadData() {
        isLoading = true

        do {
            let descriptor = FetchDescriptor<Task>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            var tasks = try modelContext.fetch(descriptor)

            // Filter by workspace if specified
            if let workspaceId = workspaceId {
                let projectDescriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.workspace?.id == workspaceId }
                )
                let workspaceProjects = try modelContext.fetch(projectDescriptor)
                let projectIds = Set(workspaceProjects.map { $0.id })
                tasks = tasks.filter { projectIds.contains($0.project?.id ?? "") }
            }

            allTasks = tasks
            applyFilters()

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func applyFilters() {
        var result = allTasks

        // Search filter
        if !filterOptions.searchText.isEmpty {
            result = result.filter { task in
                task.title.localizedCaseInsensitiveContains(filterOptions.searchText) ||
                (task.taskDescription?.localizedCaseInsensitiveContains(filterOptions.searchText) ?? false)
            }
        }

        // Status filter
        if !filterOptions.status.isEmpty {
            result = result.filter { filterOptions.status.contains($0.status.lowercased()) }
        }

        // Priority filter
        if !filterOptions.priority.isEmpty {
            result = result.filter { filterOptions.priority.contains($0.priority.lowercased()) }
        }

        // Overdue filter
        if filterOptions.showOverdueOnly {
            result = result.filter { $0.isOverdue && !$0.isCompleted }
        }

        // Blocked filter
        if filterOptions.showBlockedOnly {
            result = result.filter { $0.isBlocked }
        }

        // Due date range filter
        if let dateRange = filterOptions.dueDateRange {
            let calendar = Calendar.current
            let now = Date()

            result = result.filter { task in
                guard let dueDate = task.dueDate else { return false }

                switch dateRange {
                case .today:
                    return calendar.isDateInToday(dueDate)
                case .thisWeek:
                    return calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear)
                case .thisMonth:
                    return calendar.isDate(dueDate, equalTo: now, toGranularity: .month)
                case .custom(let start, let end):
                    return dueDate >= start && dueDate <= end
                }
            }
        }

        // Exclude completed tasks from main view (optional)
        // result = result.filter { !$0.isCompleted }

        filteredTasks = result
    }

    func toggleFilterStatus(_ status: String) {
        if filterOptions.status.contains(status) {
            filterOptions.status.remove(status)
        } else {
            filterOptions.status.insert(status)
        }
        applyFilters()
    }

    func toggleFilterPriority(_ priority: String) {
        if filterOptions.priority.contains(priority) {
            filterOptions.priority.remove(priority)
        } else {
            filterOptions.priority.insert(priority)
        }
        applyFilters()
    }

    func clearFilters() {
        filterOptions = .empty
        searchText = ""
        applyFilters()
    }

    var hasActiveFilters: Bool {
        filterOptions != .empty || !searchText.isEmpty
    }

    var activeFilterCount: Int {
        var count = 0
        if !filterOptions.status.isEmpty { count += 1 }
        if !filterOptions.priority.isEmpty { count += 1 }
        if filterOptions.showOverdueOnly { count += 1 }
        if filterOptions.showBlockedOnly { count += 1 }
        if filterOptions.dueDateRange != nil { count += 1 }
        return count
    }
}

// MARK: - Task Sort Option
enum TaskSortOption: String, CaseIterable, Identifiable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case createdAt = "Created"
    case title = "Title"
    case status = "Status"

    var id: String { rawValue }
}

// MARK: - All Tasks View
struct AllTasksView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: AllTasksViewModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTask: Task?
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var searchText = ""

    let workspaceId: String?

    init(workspaceId: String? = nil) {
        self.workspaceId = workspaceId
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                allTasksContent(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = AllTasksViewModel(modelContext: modelContext, workspaceId: workspaceId)
                    }
            }
        }
    }

    @ViewBuilder
    private func allTasksContent(viewModel: AllTasksViewModel) -> some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            searchBar(viewModel: viewModel)

            // Content
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredTasks.isEmpty {
                    emptyState(viewModel: viewModel)
                } else {
                    taskList(viewModel: viewModel)
                }
            }
        }
        .background(TaskFlowColors.background)
        .navigationTitle("All Tasks")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: TaskFlowSpacing.small) {
                    // Filter Button
                    Button(action: { showingFilters = true }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(TaskFlowColors.textPrimary)

                            if viewModel.activeFilterCount > 0 {
                                Text("\(viewModel.activeFilterCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(TaskFlowColors.primary)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }

                    // Sort Button
                    Menu {
                        ForEach(TaskSortOption.allCases) { option in
                            Button(action: {
                                viewModel.sortBy = option
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if viewModel.sortBy == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(TaskFlowColors.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            TaskFilterSheet(
                viewModel: viewModel,
                onApply: {
                    showingFilters = false
                },
                onClear: {
                    viewModel.clearFilters()
                }
            )
        }
        .task {
            viewModel.loadData()
        }
#if os(iOS)
        .refreshable {
            viewModel.loadData()
        }
#endif
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }

    // MARK: - Search Bar
    private func searchBar(viewModel: AllTasksViewModel) -> some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(TaskFlowColors.textTertiary)

            TextField("Search tasks...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _, newValue in
                    viewModel.filterOptions.searchText = newValue
                    viewModel.applyFilters()
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.filterOptions.searchText = ""
                    viewModel.applyFilters()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(TaskFlowColors.textTertiary)
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
        .padding()
    }

    // MARK: - Empty State
    private func emptyState(viewModel: AllTasksViewModel) -> some View {
        VStack(spacing: TaskFlowSpacing.large) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)

            Text(viewModel.hasActiveFilters ? "No Matching Tasks" : "No Tasks Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            Text(viewModel.hasActiveFilters
                 ? "Try adjusting your filters"
                 : "Create your first task to get started")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textSecondary)

            if viewModel.hasActiveFilters {
                Button(action: {
                    viewModel.clearFilters()
                }) {
                    Text("Clear Filters")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TaskFlowColors.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Task List
    private func taskList(viewModel: AllTasksViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: TaskFlowSpacing.small) {
                ForEach(viewModel.filteredTasks, id: \.id) { task in
                    TaskListRow(task: task)
                        .onTapGesture {
                            selectedTask = task
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Task Filter Sheet
struct TaskFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: AllTasksViewModel
    @State private var localOptions: TaskFilterOptions

    var onApply: () -> Void
    var onClear: () -> Void

    init(viewModel: AllTasksViewModel, onApply: @escaping () -> Void, onClear: @escaping () -> Void) {
        self.viewModel = viewModel
        _localOptions = State(initialValue: viewModel.filterOptions)
        self.onApply = onApply
        self.onClear = onClear
    }

    var body: some View {
        NavigationStack {
            Form {
                // Status Filter
                Section {
                    Text("Status")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    VStack(spacing: TaskFlowSpacing.small) {
                        ForEach(Task.Status.allCases, id: \.rawValue) { status in
                            FilterChip(
                                title: status.rawValue,
                                isSelected: localOptions.status.contains(status.rawValue.lowercased()),
                                color: Color(hex: status.color)
                            ) {
                                if localOptions.status.contains(status.rawValue.lowercased()) {
                                    localOptions.status.remove(status.rawValue.lowercased())
                                } else {
                                    localOptions.status.insert(status.rawValue.lowercased())
                                }
                            }
                        }
                    }
                    .padding(.vertical, TaskFlowSpacing.small)
                }

                // Priority Filter
                Section {
                    Text("Priority")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    VStack(spacing: TaskFlowSpacing.small) {
                        ForEach(Task.Priority.allCases, id: \.rawValue) { priority in
                            FilterChip(
                                title: priority.rawValue,
                                isSelected: localOptions.priority.contains(priority.rawValue.lowercased()),
                                color: Color(hex: priority.color)
                            ) {
                                if localOptions.priority.contains(priority.rawValue.lowercased()) {
                                    localOptions.priority.remove(priority.rawValue.lowercased())
                                } else {
                                    localOptions.priority.insert(priority.rawValue.lowercased())
                                }
                            }
                        }
                    }
                    .padding(.vertical, TaskFlowSpacing.small)
                }

                // Date Range Filter
                Section {
                    Text("Due Date")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    VStack(spacing: TaskFlowSpacing.small) {
                        DateFilterRow(
                            title: "Today",
                            isSelected: localOptions.dueDateRange == .today
                        ) {
                            localOptions.dueDateRange = .today
                        }

                        DateFilterRow(
                            title: "This Week",
                            isSelected: localOptions.dueDateRange == .thisWeek
                        ) {
                            localOptions.dueDateRange = .thisWeek
                        }

                        DateFilterRow(
                            title: "This Month",
                            isSelected: localOptions.dueDateRange == .thisMonth
                        ) {
                            localOptions.dueDateRange = .thisMonth
                        }

                        if localOptions.dueDateRange != nil {
                            DateFilterRow(
                                title: "Clear Date Filter",
                                isSelected: false,
                                isClearOption: true
                            ) {
                                localOptions.dueDateRange = nil
                            }
                        }
                    }
                    .padding(.vertical, TaskFlowSpacing.small)
                }

                // Special Filters
                Section {
                    Toggle("Overdue Only", isOn: $localOptions.showOverdueOnly)
                        .foregroundColor(TaskFlowColors.textPrimary)

                    Toggle("Blocked Only", isOn: $localOptions.showBlockedOnly)
                        .foregroundColor(TaskFlowColors.textPrimary)
                }
            }
            .navigationTitle("Filter Tasks")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        onClear()
                        dismiss()
                    }
                    .foregroundColor(TaskFlowColors.error)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.filterOptions = localOptions
                        viewModel.applyFilters()
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(isSelected ? color : color.opacity(0.2))
                    .frame(width: 12, height: 12)

                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.primary)
                }
            }
            .padding(.horizontal, TaskFlowSpacing.medium)
            .padding(.vertical, TaskFlowSpacing.small)
            .background(TaskFlowColors.background)
            .cornerRadius(TaskFlowRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Date Filter Row
struct DateFilterRow: View {
    let title: String
    let isSelected: Bool
    var isClearOption: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(isClearOption ? TaskFlowColors.error : TaskFlowColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.primary)
                }
            }
            .padding(.vertical, TaskFlowSpacing.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview("All Tasks") {
    NavigationStack {
        AllTasksView()
    }
}
