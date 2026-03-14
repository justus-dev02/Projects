//
//  DashboardView.swift
//  Projects
//
//  TaskFlow - Main Dashboard View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Dashboard View Model
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: DashboardStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWorkspaceId: String?

    private let dashboardService: DashboardService
    private let authService: AuthService
    private let dataService: DataService
    private var modelContext: ModelContext

    init(
        modelContext: ModelContext,
        dataService: DataService? = nil,
        dashboardService: DashboardService? = nil,
        authService: AuthService? = nil
    ) {
        self.modelContext = modelContext
        self.dataService = dataService ?? DataService(modelContext: modelContext)
        self.dashboardService = dashboardService ?? DashboardService(dataService: self.dataService)
        self.authService = authService ?? AuthService(modelContext: modelContext)
    }

    func loadStats() {
        isLoading = true

        do {
            let userId = authService.currentUser?.id
            stats = try dashboardService.getDashboardStats(for: userId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadStatsForWorkspace(_ workspaceId: String) {
        isLoading = true

        do {
            stats = try dashboardService.getWorkspaceDashboardStats(workspaceId: workspaceId)
            selectedWorkspaceId = workspaceId
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Dashboard View
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DashboardViewModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showingCreateWorkspace = false
    @State private var showingSettings = false
    @State private var createdWorkspace: Workspace?
    @State private var selectedWorkspace: Workspace?

    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                    // Header
                    dashboardHeader

                    // Stats Grid
                    statsGrid

                    // Task Lists
                    taskListsSection

                    // All Workspaces Section
                    allWorkspacesSection
                }
                .padding()
            }
            .background(TaskFlowColors.background)
            .navigationTitle("Dashboard")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(TaskFlowColors.textPrimary)
                    }
                }
            }
            .task {
                // Initialize viewModel with modelContext
                if viewModel == nil {
                    viewModel = DashboardViewModel(modelContext: modelContext)
                }
                viewModel?.loadStats()
            }
#if os(iOS)
            .refreshable {
                viewModel?.loadStats()
            }
#endif
            .sheet(isPresented: $showingCreateWorkspace) {
                CreateWorkspaceView { workspace in
                    createdWorkspace = workspace
                    showingCreateWorkspace = false
                    // Reload dashboard stats
                    viewModel?.loadStats()
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(item: $selectedWorkspace) { workspace in
                WorkspaceDetailView(workspace: workspace)
            }
        }
    }
    
    // MARK: - Dashboard Header
    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            Text("Welcome back!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            Text("Here's what's happening with your tasks today.")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textSecondary)
        }
        .padding(.bottom, TaskFlowSpacing.medium)
    }
    
    // MARK: - Stats Grid
    private var statsGrid: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad/Mac - Grid layout
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    statCards
                }
            } else {
                // iPhone - Scrollable horizontal
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TaskFlowSpacing.large) {
                        statCards
                    }
                }
            }
        }
    }
    
    private var statCards: some View {
        Group {
            TFStatCard(
                title: "Total Tasks",
                value: "\(viewModel?.stats?.totalTasks ?? 0)",
                icon: "checkmark.circle.fill",
                iconColor: TaskFlowColors.primary
            )

            TFStatCard(
                title: "Completed",
                value: "\(viewModel?.stats?.completedTasks ?? 0)",
                icon: "checkmark.seal.fill",
                iconColor: TaskFlowColors.success,
                trend: viewModel?.stats?.taskCompletionRate,
                trendUp: true
            )

            TFStatCard(
                title: "In Progress",
                value: "\(viewModel?.stats?.inProgressTasks ?? 0)",
                icon: "arrow.triangle.2.circlepath",
                iconColor: TaskFlowColors.statusInProgress
            )

            TFStatCard(
                title: "Overdue",
                value: "\(viewModel?.stats?.overdueTasks ?? 0)",
                icon: "exclamationmark.triangle.fill",
                iconColor: TaskFlowColors.error
            )
        }
    }
    
    // MARK: - Task Lists Section
    private var taskListsSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            Text("Task Overview")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: TaskFlowSpacing.large) {
                // Due Today
                TFCard {
                    VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .foregroundColor(TaskFlowColors.warning)
                            Text("Due Today")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(TaskFlowColors.textPrimary)
                            Spacer()
                        }
                        
                        if let dueToday = viewModel?.stats?.dueToday, !dueToday.isEmpty {
                            VStack(spacing: TaskFlowSpacing.small) {
                                ForEach(dueToday.prefix(4), id: \.id) { task in
                                    TaskListItemView(task: task)
                                }
                            }
                        } else {
                            TFEmptyStateCard(
                                icon: "checkmark.circle",
                                title: "All Clear",
                                message: "No tasks due today",
                                actionTitle: nil
                            )
                        }
                    }
                }

                // High Priority
                TFCard {
                    VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(TaskFlowColors.priorityHigh)
                            Text("High Priority")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(TaskFlowColors.textPrimary)
                            Spacer()
                        }

                        if let highPriority = viewModel?.stats?.highPriority, !highPriority.isEmpty {
                            VStack(spacing: TaskFlowSpacing.small) {
                                ForEach(highPriority.prefix(4), id: \.id) { task in
                                    TaskListItemView(task: task)
                                }
                            }
                        } else {
                            TFEmptyStateCard(
                                icon: "star",
                                title: "No Priority Tasks",
                                message: "All tasks are normal priority",
                                actionTitle: nil
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - All Workspaces Section
    private var allWorkspacesSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            HStack {
                Text("My Workspaces")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Spacer()

                Button(action: {
                    showingCreateWorkspace = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(TaskFlowColors.primary)
                }
            }

            if workspaces.isEmpty {
                TFEmptyStateCard(
                    icon: "briefcase",
                    title: "No Workspaces",
                    message: "Create your first workspace to get started.",
                    actionTitle: "Create Workspace",
                    action: {
                        showingCreateWorkspace = true
                    }
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    ForEach(workspaces.filter { !$0.isArchived }, id: \.id) { workspace in
                        WorkspaceCard(workspace: workspace)
                            .onTapGesture {
                                selectedWorkspace = workspace
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Task List Item View
struct TaskListItemView: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Status Indicator
            Circle()
                .fill(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.statusInProgress)
                .frame(width: 8, height: 8)
            
            // Task Info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    Text(formatDueDate(dueDate))
                        .font(.system(size: 11))
                        .foregroundColor(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                }
            }
            
            Spacer()
            
            // Priority Indicator
            Image(systemName: priorityIcon(for: task.priority))
                .font(.system(size: 10))
                .foregroundColor(priorityColor(for: task.priority))
        }
        .padding(.vertical, TaskFlowSpacing.small)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func priorityIcon(for priority: String) -> String {
        switch priority.lowercased() {
        case "low": return "arrow.down"
        case "medium": return "arrow.left.and.right"
        case "high": return "arrow.up.right"
        case "urgent": return "exclamationmark.triangle.fill"
        default: return "arrow.left.and.right"
        }
    }
    
    private func priorityColor(for priority: String) -> Color {
        switch priority.lowercased() {
        case "low": return TaskFlowColors.priorityLow
        case "medium": return TaskFlowColors.priorityMedium
        case "high": return TaskFlowColors.priorityHigh
        case "urgent": return TaskFlowColors.priorityUrgent
        default: return TaskFlowColors.priorityMedium
        }
    }
}

// MARK: - Workspace Overview Card
struct WorkspaceOverviewCard: View {
    let workspace: WorkspaceOverview
    
    var body: some View {
        TFCard {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                // Header
                HStack {
                    Circle()
                        .fill(Color(hex: workspace.workspaceColor))
                        .frame(width: 12, height: 12)
                    
                    Text(workspace.workspaceName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    Spacer()
                }
                
                // Stats
                HStack(spacing: TaskFlowSpacing.large) {
                    StatItem(
                        value: "\(workspace.totalProjects)",
                        label: "Projects",
                        color: TaskFlowColors.primary
                    )
                    
                    StatItem(
                        value: "\(workspace.totalTasks)",
                        label: "Tasks",
                        color: TaskFlowColors.statusInProgress
                    )
                    
                    StatItem(
                        value: "\(workspace.completedTasks)",
                        label: "Done",
                        color: TaskFlowColors.success
                    )
                }
                
                // Progress
                VStack(spacing: TaskFlowSpacing.small) {
                    HStack {
                        Text("Progress")
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(workspace.progressPercentage))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(TaskFlowColors.textPrimary)
                    }
                    
                    TFProgressBar(progress: workspace.progressPercentage, height: 6)
                }
            }
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(TaskFlowColors.textTertiary)
        }
    }
}

// MARK: - Workspace Card
struct WorkspaceCard: View {
    let workspace: Workspace

    var body: some View {
        TFCard {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: workspace.color).opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: workspace.icon)
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: workspace.color))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(TaskFlowColors.textPrimary)
                            .lineLimit(1)

                        if let workspaceDescription = workspace.workspaceDescription {
                            Text(workspaceDescription)
                                .font(.system(size: 12))
                                .foregroundColor(TaskFlowColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }

                Divider()

                // Stats
                HStack(spacing: TaskFlowSpacing.large) {
                    WorkspaceStatItem(
                        value: "\(workspace.projectCount)",
                        label: "Projects",
                        icon: "folder.fill"
                    )

                    WorkspaceStatItem(
                        value: "\(workspace.memberCount)",
                        label: "Members",
                        icon: "person.2.fill"
                    )

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Workspace Stat Item
struct WorkspaceStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(TaskFlowColors.textTertiary)

            VStack(alignment: .leading, spacing: -2) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
        }
    }
}

// MARK: - Preview
#Preview("Dashboard") {
    NavigationStack {
        DashboardView()
    }
}
