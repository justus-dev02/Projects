//
//  TodayOverviewView.swift
//  Projects
//
//  TaskFlow - Today Overview View showing all tasks and deadlines for current day
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Today Overview View Model
@MainActor
class TodayOverviewViewModel: ObservableObject {
    @Published var tasksDueToday: [Task] = []
    @Published var overdueTasks: [Task] = []
    @Published var tasksDueTomorrow: [Task] = []
    @Published var allProjects: [Project] = []
    @Published var selectedTask: Task?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let modelContext: ModelContext
    private let taskRepo: TaskRepository
    private let projectRepo: ProjectRepository
    private let workspaceId: String?

    init(
        modelContext: ModelContext,
        workspaceId: String? = nil,
        taskRepo: TaskRepository? = nil,
        projectRepo: ProjectRepository? = nil
    ) {
        self.modelContext = modelContext
        self.workspaceId = workspaceId
        let dataService = DataService(modelContext: modelContext)
        self.taskRepo = taskRepo ?? TaskRepository(dataService: dataService)
        self.projectRepo = projectRepo ?? ProjectRepository(dataService: dataService)
    }

    func loadData() {
        isLoading = true

        do {
            // Fetch all tasks
            let descriptor = FetchDescriptor<Task>(
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            let allTasks = try modelContext.fetch(descriptor)

            // Filter tasks
            tasksDueToday = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInToday(dueDate) && !task.isCompleted
            }

            overdueTasks = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < Date() && !task.isCompleted
            }

            tasksDueTomorrow = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInTomorrow(dueDate) && !task.isCompleted
            }

            // Filter by workspace if specified
            if let workspaceId = workspaceId {
                let projectDescriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.workspace?.id == workspaceId },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                allProjects = try modelContext.fetch(projectDescriptor)

                // Filter tasks for this workspace
                let workspaceProjectIds = Set(allProjects.map { $0.id })
                tasksDueToday = tasksDueToday.filter { workspaceProjectIds.contains($0.project?.id ?? "") }
                overdueTasks = overdueTasks.filter { workspaceProjectIds.contains($0.project?.id ?? "") }
                tasksDueTomorrow = tasksDueTomorrow.filter { workspaceProjectIds.contains($0.project?.id ?? "") }
            } else {
                // Load all projects if no workspace filter
                let projectDescriptor = FetchDescriptor<Project>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                allProjects = try modelContext.fetch(projectDescriptor)
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleTaskCompletion(_ task: Task) throws {
        let newStatus = task.isCompleted ? "inProgress" : "done"
        try taskRepo.updateTask(task, status: newStatus)

        // Update local arrays
        if task.isCompleted {
            // Task was completed, now incomplete - add back to appropriate list
            if let dueDate = task.dueDate {
                if Calendar.current.isDateInToday(dueDate) {
                    tasksDueToday.append(task)
                } else if Calendar.current.isDateInTomorrow(dueDate) {
                    tasksDueTomorrow.append(task)
                }
            }
        } else {
            // Task is now completed - remove from lists
            tasksDueToday.removeAll { $0.id == task.id }
            overdueTasks.removeAll { $0.id == task.id }
            tasksDueTomorrow.removeAll { $0.id == task.id }
        }
    }

    var totalTasksCount: Int {
        tasksDueToday.count + overdueTasks.count + tasksDueTomorrow.count
    }

    var completedTodayCount: Int {
        // Count tasks completed today
        let descriptor = FetchDescriptor<Task>(
            predicate: #Predicate { $0.status == "done" },
            sortBy: []
        )
        guard let allCompleted = try? modelContext.fetch(descriptor) else { return 0 }
        return allCompleted.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
    }
}

// MARK: - Today Overview View
struct TodayOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayOverviewViewModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedTask: Task?
    @State private var showingTaskDetail = false

    let workspaceId: String?

    init(workspaceId: String? = nil) {
        self.workspaceId = workspaceId
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                todayOverviewContent(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = TodayOverviewViewModel(modelContext: modelContext, workspaceId: workspaceId)
                    }
            }
        }
    }

    @ViewBuilder
    private func todayOverviewContent(viewModel: TodayOverviewViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                // Date Header
                dateHeader

                // Stats Summary
                statsSummary

                // Overdue Tasks
                if !viewModel.overdueTasks.isEmpty {
                    taskSection(
                        title: "Overdue",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: TaskFlowColors.error,
                        tasks: viewModel.overdueTasks
                    )
                }

                // Tasks Due Today
                taskSection(
                    title: "Due Today",
                    icon: "sun.max.fill",
                    iconColor: TaskFlowColors.warning,
                    tasks: viewModel.tasksDueToday
                )

                // Tasks Due Tomorrow
                if !viewModel.tasksDueTomorrow.isEmpty {
                    taskSection(
                        title: "Due Tomorrow",
                        icon: "sunrise.fill",
                        iconColor: TaskFlowColors.primary,
                        tasks: viewModel.tasksDueTomorrow
                    )
                }

                // All Projects
                projectsSection
            }
            .padding()
        }
        .background(TaskFlowColors.background)
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

    // MARK: - Date Header
    private var dateHeader: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
            Text(formattedDate)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(TaskFlowColors.textPrimary)

            Text("Here's what's on your plate today")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textSecondary)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }

    // MARK: - Stats Summary
    private var statsSummary: some View {
        HStack(spacing: TaskFlowSpacing.large) {
            StatChip(
                value: "\(viewModel?.totalTasksCount ?? 0)",
                label: "Total Tasks",
                color: TaskFlowColors.primary,
                icon: "checkmark.seal.fill"
            )

            StatChip(
                value: "\(viewModel?.overdueTasks.count ?? 0)",
                label: "Overdue",
                color: TaskFlowColors.error,
                icon: "exclamationmark.triangle.fill"
            )

            StatChip(
                value: "\(viewModel?.tasksDueToday.count ?? 0)",
                label: "Due Today",
                color: TaskFlowColors.warning,
                icon: "sun.max.fill"
            )

            StatChip(
                value: "\(viewModel?.completedTodayCount ?? 0)",
                label: "Completed",
                color: TaskFlowColors.success,
                icon: "checkmark.circle.fill"
            )
        }
    }

    // MARK: - Task Section
    @ViewBuilder
    private func taskSection(
        title: String,
        icon: String,
        iconColor: Color,
        tasks: [Task]
    ) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            HStack {
                HStack(spacing: TaskFlowSpacing.small) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                }

                Spacer()

                Text("\(tasks.count)")
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textTertiary)
                    .padding(.horizontal, TaskFlowSpacing.small)
                    .padding(.vertical, 2)
                    .background(TaskFlowColors.background)
                    .cornerRadius(TaskFlowRadius.small)
            }

            VStack(spacing: TaskFlowSpacing.small) {
                ForEach(tasks, id: \.id) { task in
                    QuickTaskRow(task: task)
                        .onTapGesture {
                            selectedTask = task
                        }
                }
            }
        }
    }

    // MARK: - Projects Section
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            HStack {
                Text("All Projects")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Spacer()

                Text("\(viewModel?.allProjects.count ?? 0)")
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }

            if viewModel?.allProjects.isEmpty ?? true {
                TFEmptyStateCard(
                    icon: "folder",
                    title: "No Projects",
                    message: "Create your first project to get started",
                    actionTitle: nil
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    ForEach(viewModel?.allProjects ?? [], id: \.id) { project in
                        ProjectOverviewCard(project: project)
                    }
                }
            }
        }
    }
}

// MARK: - Stat Chip
struct StatChip: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: TaskFlowSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
        }
        .padding(.horizontal, TaskFlowSpacing.medium)
        .padding(.vertical, TaskFlowSpacing.small)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Quick Task Row
struct QuickTaskRow: View {
    let task: Task
    @State private var isCompleted: Bool = false

    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Completion Button
            Button(action: {
                isCompleted.toggle()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isCompleted ? TaskFlowColors.success : TaskFlowColors.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())

            // Task Info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCompleted ? TaskFlowColors.textTertiary : TaskFlowColors.textPrimary)
                    .strikethrough(isCompleted)
                    .lineLimit(1)

                HStack(spacing: TaskFlowSpacing.small) {
                    if let project = task.project {
                        Text(project.name)
                            .font(.system(size: 11))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }

                    TFPriorityBadge(priority: task.priority, size: .small, style: .outline)
                }
            }

            Spacer()

            // Due Time
            if let dueDate = task.dueDate {
                Text(formatDueTime(dueDate))
                    .font(.system(size: 12))
                    .foregroundColor(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
            }

            // Navigation Indicator
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
        .onChange(of: isCompleted) { _, newValue in
            // In production, call viewModel.toggleTaskCompletion(task)
        }
    }

    private func formatDueTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Project Overview Card
struct ProjectOverviewCard: View {
    let project: Project

    var body: some View {
        TFCard {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: project.color).opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: project.icon)
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: project.color))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(TaskFlowColors.textPrimary)
                            .lineLimit(1)

                        TFStatusBadge(status: project.status, size: .small)
                    }

                    Spacer()
                }

                // Progress
                VStack(spacing: TaskFlowSpacing.small) {
                    HStack {
                        Text("\(project.completedTaskCount) of \(project.taskCount) tasks")
                            .font(.system(size: 11))
                            .foregroundColor(TaskFlowColors.textTertiary)

                        Spacer()

                        Text("\(Int(project.progressPercentage))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(TaskFlowColors.textPrimary)
                    }

                    TFTaskProgress(
                        completed: project.completedTaskCount,
                        total: project.taskCount,
                        height: 4
                    )
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Today Overview") {
    NavigationStack {
        TodayOverviewView()
    }
}
