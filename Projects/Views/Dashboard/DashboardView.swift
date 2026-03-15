//
//  DashboardView.swift
//  Projects
//
//  TaskFlow - Main Dashboard View with Workspace Dropdown
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
    @Published var selectedWorkspace: Workspace?

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

            // Load workspace details
            let descriptor = FetchDescriptor<Workspace>(
                predicate: #Predicate { $0.id == workspaceId }
            )
            selectedWorkspace = try modelContext.fetch(descriptor).first

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

    @State private var showingSettings = false
    @State private var selectedWorkspaceId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Top Toolbar with Workspace Dropdown
            topToolbar

            Divider()
                .foregroundColor(TaskFlowColors.border)

            // Main Content
            ScrollView {
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                    // Today Overview (replaces old stats and task lists)
                    TodayOverviewView(workspaceId: selectedWorkspaceId)
                }
                .padding()
            }
            .background(TaskFlowColors.background)
        }
        .background(TaskFlowColors.background)
        .navigationTitle("")
#if os(iOS)
        .navigationBarHidden(true)
#endif
        .toolbar(.hidden)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Workspace Dropdown
            WorkspaceDropdownView(
                selectedWorkspaceId: $selectedWorkspaceId,
                onWorkspaceSelected: { workspace in
                    viewModel?.loadStatsForWorkspace(workspace.id)
                }
            )

            Spacer()

            // Settings Button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .padding(TaskFlowSpacing.small)
            }
        }
        .padding(.horizontal, TaskFlowSpacing.large)
        .padding(.vertical, TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
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
