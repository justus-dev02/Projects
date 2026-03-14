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
    @Environment(\.modelContext) private var modelContext
    @Query private var workspaces: [Workspace]
    
    @Published var stats: DashboardStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWorkspaceId: String?
    
    private let dashboardService: DashboardService
    private let authService: AuthService
    private let dataService: DataService

    init(
        dataService: DataService? = nil,
        dashboardService: DashboardService? = nil,
        authService: AuthService? = nil
    ) {
        self.dataService = dataService ?? DataService.shared
        self.dashboardService = dashboardService ?? DashboardService(dataService: self.dataService)
        self.authService = authService ?? AuthService.shared
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
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                // Header
                dashboardHeader
                
                // Stats Grid
                statsGrid
                
                // Task Lists
                taskListsSection
                
                // Workspace Overview
                workspaceOverviewSection
            }
            .padding()
        }
        .background(TaskFlowColors.background)
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .task {
            viewModel.loadStats()
        }
        .refreshable {
            viewModel.loadStats()
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
                value: "\(viewModel.stats?.totalTasks ?? 0)",
                icon: "checkmark.circle.fill",
                iconColor: TaskFlowColors.primary
            )
            
            TFStatCard(
                title: "Completed",
                value: "\(viewModel.stats?.completedTasks ?? 0)",
                icon: "checkmark.seal.fill",
                iconColor: TaskFlowColors.success,
                trend: viewModel.stats?.taskCompletionRate,
                trendUp: true
            )
            
            TFStatCard(
                title: "In Progress",
                value: "\(viewModel.stats?.inProgressTasks ?? 0)",
                icon: "arrow.triangle.2.circlepath",
                iconColor: TaskFlowColors.statusInProgress
            )
            
            TFStatCard(
                title: "Overdue",
                value: "\(viewModel.stats?.overdueTasks ?? 0)",
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
                        
                        if let dueToday = viewModel.stats?.dueToday, !dueToday.isEmpty {
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
                        
                        if let highPriority = viewModel.stats?.highPriority, !highPriority.isEmpty {
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
    
    // MARK: - Workspace Overview Section
    private var workspaceOverviewSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            Text("Workspaces")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            if let workspaceStats = viewModel.stats?.workspaceStats, !workspaceStats.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    ForEach(workspaceStats, id: \.workspaceId) { ws in
                        WorkspaceOverviewCard(workspace: ws)
                    }
                }
            } else {
                TFEmptyStateCard(
                    icon: "briefcase",
                    title: "No Workspaces",
                    message: "Create your first workspace to get started.",
                    actionTitle: "Create Workspace",
                    action: {}
                )
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

// MARK: - Preview
#Preview("Dashboard") {
    NavigationStack {
        DashboardView()
    }
}
