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
    private let modelContext: ModelContext

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
        modelContext: ModelContext,
        dataService: DataService? = nil,
        workspaceRepo: WorkspaceRepository? = nil,
        projectRepo: ProjectRepository? = nil,
        dashboardService: DashboardService? = nil
    ) {
        self.workspace = workspace
        self.modelContext = modelContext
        self.dataService = dataService ?? DataService(modelContext: modelContext)
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
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkspaceDetailViewModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let workspace: Workspace

    @State private var navigateToProject: Project? = nil
    @State private var showingCreateProject = false

    var body: some View {
        Group {
            if let vm = viewModel {
                workspaceContent(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = WorkspaceDetailViewModel(
                    workspace: workspace,
                    modelContext: modelContext
                )
                viewModel?.loadProjects()
            }
        }
    }

    @ViewBuilder
    private func workspaceContent(viewModel: WorkspaceDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xxLarge) {
                // Header
                workspaceHeader(viewModel: viewModel)
                    .padding()
                    .liquidGlass(style: .regular, cornerRadius: 28, tint: Color(hex: viewModel.workspace.color).opacity(0.05))

                // Stats Summary
                statsSection(viewModel: viewModel)

                // Projects Section
                projectsSection(viewModel: viewModel)
            }
            .padding()
        }
        .background(
            ZStack {
                TaskFlowColors.background
                Color(hex: viewModel.workspace.color).opacity(0.02)
            }
            .ignoresSafeArea()
        )
        .navigationTitle(viewModel.workspace.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                TFButton(title: "New Project", style: .primary, size: .small, icon: "plus") {
                    showingCreateProject = true
                }
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectView(viewModel: viewModel) { project in
                showingCreateProject = false
                viewModel.loadProjects()
            }
        }
        .navigationDestination(item: $navigateToProject) { project in
            ProjectDetailView(project: project)
        }
    }
    
    // MARK: - Workspace Header
    private func workspaceHeader(viewModel: WorkspaceDetailViewModel) -> some View {
        HStack(spacing: TaskFlowSpacing.large) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: viewModel.workspace.color).opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: viewModel.workspace.icon)
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: viewModel.workspace.color))
            }

            // Info
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                Text(viewModel.workspace.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                if let workspaceDescription = viewModel.workspace.workspaceDescription {
                    Text(workspaceDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TaskFlowColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: TaskFlowSpacing.medium) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                        Text("\(viewModel.workspace.projectCount)")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("\(viewModel.workspace.memberCount)")
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(TaskFlowColors.textTertiary)
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    // MARK: - Stats Section
    private func statsSection(viewModel: WorkspaceDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            Text("Overview")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(TaskFlowColors.textPrimary)

            if let stats = viewModel.stats {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    StatChip(
                        value: "\(stats.totalProjects)",
                        label: "Projects",
                        color: TaskFlowColors.primary,
                        icon: "folder.fill"
                    )

                    StatChip(
                        value: "\(stats.activeProjects)",
                        label: "Active",
                        color: TaskFlowColors.success,
                        icon: "play.circle.fill"
                    )

                    StatChip(
                        value: "\(stats.totalTasks)",
                        label: "Tasks",
                        color: TaskFlowColors.warning,
                        icon: "checkmark.seal.fill"
                    )
                    
                    StatChip(
                        value: "\(stats.completedProjects)",
                        label: "Completed",
                        color: Color.purple,
                        icon: "checkmark.circle.fill"
                    )
                }
            }
        }
    }
    
    // MARK: - Projects Section
    private func projectsSection(viewModel: WorkspaceDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            HStack {
                Text("Projects")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Spacer()

                if !viewModel.projects.isEmpty {
                    Text("\(viewModel.projects.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TaskFlowColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(TaskFlowColors.background)
                        .cornerRadius(8)
                }
            }

            if viewModel.projects.isEmpty {
                TFEmptyStateCard(
                    icon: "folder.badge.plus",
                    title: "Ready to start?",
                    message: "Create your first project to organize tasks.",
                    actionTitle: "Create Project",
                    action: {
                        showingCreateProject = true
                    }
                )
            } else {
                LazyVStack(spacing: TaskFlowSpacing.large) {
                    ForEach(viewModel.projects, id: \.id) { project in
                        ProjectCard(project: project)
                            .onTapGesture {
                                navigateToProject = project
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
        VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: project.color).opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: project.icon)
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: project.color))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .lineLimit(1)

                    TFStatusBadge(status: project.status, size: .small, style: .soft)
                }

                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }

            // Description
            if let projectDescription = project.projectDescription {
                Text(projectDescription)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .lineLimit(2)
            }

            // Progress & Footer
            VStack(spacing: TaskFlowSpacing.medium) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TaskFlowColors.success)
                        Text("\(project.completedTaskCount)/\(project.taskCount)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(TaskFlowColors.textSecondary)

                    Spacer()

                    Text("\(Int(project.progressPercentage))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                }

                TFTaskProgress(
                    completed: project.completedTaskCount,
                    total: project.taskCount,
                    height: 8
                )
            }
        }
        .padding(TaskFlowSpacing.xLarge)
        .liquidGlass(style: .regular, cornerRadius: 24, tint: Color(hex: project.color).opacity(0.05))
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
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: WorkspaceDetailViewModel

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#4ECDC4"
    @State private var selectedIcon = "folder.fill"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let icons = ["folder.fill", "star.fill", "bolt.fill", "heart.fill", "flame.fill", "target", "globe", "sparkles"]
    let colors = ["#4ECDC4", "#2D5BFF", "#FF6B6B", "#00BA88", "#FFB020", "#A855F7", "#45B7D1", "#FF4757"]

    var onSave: (Project) -> Void

    init(viewModel: WorkspaceDetailViewModel, onSave: @escaping (Project) -> Void) {
        self.viewModel = viewModel
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TaskFlowSpacing.xLarge) {
                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
                        // Basic Info Section
                        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                            TFTextField(
                                title: "Name",
                                placeholder: "Enter project name",
                                text: $name
                            )
                            
                            TFTextField(
                                title: "Description (Optional)",
                                placeholder: "Describe your project",
                                text: $description,
                                multiline: true,
                                minLineCount: 3
                            )
                        }
                        .padding()
                        .liquidGlass(style: .regular, cornerRadius: 20)

                        // Appearance Section
                        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                            Text("Appearance")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(TaskFlowColors.textPrimary)

                            Text("Color")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(TaskFlowColors.textSecondary)

                            TFColorPicker(selectedColor: $selectedColor, colors: colors, columns: 8)

                            Divider()
                                .padding(.vertical, TaskFlowSpacing.xs)

                            Text("Icon")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(TaskFlowColors.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TaskFlowSpacing.medium), count: 8), spacing: TaskFlowSpacing.medium) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color.primary.opacity(0.05))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : TaskFlowColors.textSecondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding()
                        .liquidGlass(style: .regular, cornerRadius: 20)
                    }
                    .padding()
                }
            }
            .background(TaskFlowColors.background.ignoresSafeArea())
            .navigationTitle("New Project")
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
                        createProject()
                    }
                    .disabled(name.isEmpty)
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

        do {
            let project = try viewModel.createProject(
                name: name,
                projectDescription: description.isEmpty ? nil : description,
                color: selectedColor,
                icon: selectedIcon
            )

            onSave(project)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview("Workspace Detail") {
    let workspace = Workspace(name: "Marketing", workspaceDescription: "Marketing team workspace", color: "#2D5BFF", icon: "briefcase.fill")
    WorkspaceDetailView(workspace: workspace)
}
