//
//  WorkspaceDetailView.swift
//  Projects
//
//  TaskFlow - Workspace Detail View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Workspace Detail View Model
@MainActor
class WorkspaceDetailViewModel: ObservableObject {
    let workspace: Workspace
    @Environment(\.modelContext) private var modelContext
    
    @Published var projects: [Project] = []
    @Published var stats: WorkspaceStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateProject = false
    @Published var selectedProject: Project?
    
    private let workspaceRepo: WorkspaceRepository
    private let projectRepo: ProjectRepository
    private let dashboardService: DashboardService
    private let dataService: DataService

    init(
        workspace: Workspace,
        dataService: DataService? = nil,
        workspaceRepo: WorkspaceRepository? = nil,
        projectRepo: ProjectRepository? = nil,
        dashboardService: DashboardService? = nil
    ) {
        self.workspace = workspace
        self.dataService = dataService ?? DataService.shared
        self.workspaceRepo = workspaceRepo ?? WorkspaceRepository(dataService: self.dataService)
        self.projectRepo = projectRepo ?? ProjectRepository(dataService: self.dataService)
        self.dashboardService = dashboardService ?? DashboardService(dataService: self.dataService)
    }

    func loadProjects() {
        isLoading = true

        do {
            projects = try projectRepo.getProjectsForWorkspace(workspaceId: workspace.id)
            stats = try workspaceRepo.getWorkspaceStats(workspaceId: workspace.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createProject(name: String, projectDescription: String?, color: String, icon: String) throws -> Project {
        let project = try projectRepo.createProject(
            name: name,
            projectDescription: projectDescription,
            color: color,
            icon: icon,
            workspace: workspace
        )
        projects.append(project)
        return project
    }
    
    func deleteProject(_ project: Project) throws {
        try projectRepo.deleteProject(project)
        projects.removeAll { $0.id == project.id }
    }
}

// MARK: - Workspace Detail View
struct WorkspaceDetailView: View {
    @StateObject private var viewModel: WorkspaceDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init(workspace: Workspace) {
        _viewModel = StateObject(wrappedValue: WorkspaceDetailViewModel(workspace: workspace))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                // Header
                workspaceHeader
                
                // Stats
                statsSection
                
                // Projects
                projectsSection
            }
            .padding()
        }
        .background(TaskFlowColors.background)
        .navigationTitle(viewModel.workspace.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TFButton(title: "New Project", style: .primary, size: .small, icon: "plus") {
                    viewModel.showingCreateProject = true
                }
            }
        }
        .task {
            viewModel.loadProjects()
        }
        .sheet(isPresented: $viewModel.showingCreateProject) {
            CreateProjectView { project in
                viewModel.selectedProject = project
                viewModel.showingCreateProject = false
            }
        }
    }
    
    // MARK: - Workspace Header
    private var workspaceHeader: some View {
        TFCard {
            HStack(spacing: TaskFlowSpacing.large) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: viewModel.workspace.color).opacity(0.15))
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: viewModel.workspace.icon)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: viewModel.workspace.color))
                }
                
                // Info
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                    Text(viewModel.workspace.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    if let workspaceDescription = viewModel.workspace.workspaceDescription {
                        Text(workspaceDescription)
                            .font(.system(size: 14))
                            .foregroundColor(TaskFlowColors.textSecondary)
                    }
                    
                    HStack(spacing: TaskFlowSpacing.medium) {
                        SwiftUI.Label("\(viewModel.workspace.projectCount) Projects", systemImage: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textTertiary)

                        SwiftUI.Label("\(viewModel.workspace.memberCount) Members", systemImage: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Stats Section
    private var statsSection: some View {
        Group {
            if let stats = viewModel.stats {
                Text("Overview")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    TFStatCard(
                        title: "Total Projects",
                        value: "\(stats.totalProjects)",
                        icon: "folder.fill",
                        iconColor: TaskFlowColors.primary
                    )
                    
                    TFStatCard(
                        title: "Active",
                        value: "\(stats.activeProjects)",
                        icon: "play.circle.fill",
                        iconColor: TaskFlowColors.success
                    )
                    
                    TFStatCard(
                        title: "Completed",
                        value: "\(stats.completedProjects)",
                        icon: "checkmark.circle.fill",
                        iconColor: TaskFlowColors.statusDone
                    )
                    
                    TFStatCard(
                        title: "Tasks",
                        value: "\(stats.totalTasks)",
                        icon: "checkmark.seal.fill",
                        iconColor: TaskFlowColors.statusInProgress
                    )
                }
            }
        }
    }
    
    // MARK: - Projects Section
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            HStack {
                Text("Projects")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                Spacer()
                
                if !viewModel.projects.isEmpty {
                    Text("\(viewModel.projects.count) total")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
            
            if viewModel.projects.isEmpty {
                TFEmptyStateCard(
                    icon: "folder",
                    title: "No Projects Yet",
                    message: "Create your first project to start organizing tasks.",
                    actionTitle: "Create Project",
                    action: {
                        viewModel.showingCreateProject = true
                    }
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    ForEach(viewModel.projects, id: \.id) { project in
                        ProjectCard(project: project)
                            .onTapGesture {
                                viewModel.selectedProject = project
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Project Card
struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        NavigationLink(destination: ProjectDetailView(project: project)) {
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
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(TaskFlowColors.textPrimary)
                                .lineLimit(1)
                            
                            TFStatusBadge(status: project.status, size: .small)
                        }
                        
                        Spacer()
                    }
                    
                    // Description
                    if let projectDescription = project.projectDescription {
                        Text(projectDescription)
                            .font(.system(size: 13))
                            .foregroundColor(TaskFlowColors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    // Progress
                    VStack(spacing: TaskFlowSpacing.small) {
                        HStack {
                            Text("\(project.completedTaskCount) of \(project.taskCount) tasks")
                                .font(.system(size: 12))
                                .foregroundColor(TaskFlowColors.textTertiary)
                            
                            Spacer()
                            
                            Text("\(Int(project.progressPercentage))%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(TaskFlowColors.textPrimary)
                        }
                        
                        TFTaskProgress(
                            completed: project.completedTaskCount,
                            total: project.taskCount,
                            height: 6
                        )
                    }
                    
                    // Footer
                    HStack(spacing: TaskFlowSpacing.medium) {
                        if let dueDate = project.dueDate {
                            SwiftUI.Label(formatDate(dueDate), systemImage: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(TaskFlowColors.textTertiary)
                        }
                        
                        Spacer()
                        
                        if let members = project.members, !members.isEmpty {
                            HStack(spacing: -8) {
                                ForEach(members.prefix(3), id: \.id) { member in
                                    if let user = member.user {
                                        TFAvatar(name: user.displayName, colorHex: user.avatarColor, size: .xSmall)
                                    }
                                }
                                
                                if members.count > 3 {
                                    Text("+\(members.count - 3)")
                                        .font(.system(size: 10))
                                        .foregroundColor(TaskFlowColors.textTertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Create Project View
struct CreateProjectView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#4ECDC4"
    @State private var selectedIcon = "folder.fill"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let icons = ["folder.fill", "star.fill", "bolt.fill", "heart.fill", "flame.fill", "target", "globe", "sparkles"]
    let colors = ["#4ECDC4", "#2D5BFF", "#FF6B6B", "#00BA88", "#FFB020", "#A855F7", "#45B7D1", "#FF4757"]
    
    var onSave: (Project) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TFTextField(
                        title: "Name",
                        placeholder: "Enter project name",
                        text: $name,
                        errorMessage: name.isEmpty && errorMessage != nil ? "Name is required" : nil
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
                
                Section {
                    TFTextField(
                        title: "Description (Optional)",
                        placeholder: "Describe your project",
                        text: $description,
                        multiline: true,
                        minLineCount: 3
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
                
                Section {
                    Text("Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    TFColorPicker(selectedColor: $selectedColor, colors: colors, columns: 8)
                        .padding(.vertical, TaskFlowSpacing.medium)
                }
                
                Section {
                    Text("Icon")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TaskFlowSpacing.medium), count: 8), spacing: TaskFlowSpacing.medium) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? TaskFlowColors.primary.opacity(0.1) : TaskFlowColors.background)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIcon == icon ? TaskFlowColors.primary : TaskFlowColors.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
            }
            .navigationTitle("New Project")
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
                        createProject()
                    }
                }
            }
        }
    }
    
    private func createProject() {
        guard !name.isEmpty else {
            errorMessage = "Name is required"
            return
        }
        
        isLoading = true
        
        // Project creation handled by parent view model
        // This is a simplified version
        isLoading = false
        dismiss()
    }
}

// MARK: - Preview
#Preview("Workspace Detail") {
    let workspace = Workspace(name: "Marketing", workspaceDescription: "Marketing team workspace", color: "#2D5BFF", icon: "briefcase.fill")
    WorkspaceDetailView(workspace: workspace)
}
