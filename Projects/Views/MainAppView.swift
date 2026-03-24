//
//  MainAppView.swift
//  Projects
//
//  TaskFlow - Main App View with Unified Navigation
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Main App View Model
@MainActor
class MainAppViewModel: ObservableObject {
    @Published var selectedTab: MainNavigationTab = .dashboard
    @Published var selectedWorkspaceId: String?
    @Published var navigationViewModel: MainNavigationViewModel

    init() {
        self.navigationViewModel = MainNavigationViewModel()
    }

    func selectTab(_ tab: MainNavigationTab) {
        selectedTab = tab
    }

    func selectWorkspace(_ workspaceId: String) {
        selectedWorkspaceId = workspaceId
    }
}

// MARK: - Main App View
struct MainAppView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel: MainAppViewModel

    init() {
        _viewModel = StateObject(wrappedValue: MainAppViewModel())
    }

    var body: some View {
        Group {
            if isRegularSize {
                // iPad/Mac - Sidebar/Top Navigation
                iPadMacLayout
            } else {
                // iPhone - Bottom Tab Bar
                iPhoneLayout
            }
        }
        .background(TaskFlowColors.background)
    }

    private var isRegularSize: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - iPhone Layout (Bottom Tab Bar)
    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            // Content Area
            NavigationStack {
                ZStack {
                    switch viewModel.selectedTab {
                    case .dashboard:
                        DashboardView()
                    case .tasks:
                        AllTasksView(workspaceId: viewModel.selectedWorkspaceId)
                    case .projects:
                        WorkspaceProjectsView(workspaceId: viewModel.selectedWorkspaceId)
                    case .messages:
                        WorkspaceMessagesView(workspaceId: viewModel.selectedWorkspaceId)
                    case .settings:
                        SettingsView()
                    }
                }
                .padding(.bottom, 90) // Space for floating bar
            }

            // Bottom Navigation Bar
            MainNavigationBar(
                viewModel: viewModel.navigationViewModel,
                onTabSelected: { tab in
                    viewModel.selectTab(tab)
                }
            )
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - iPad/Mac Layout (Top Navigation)
    private var iPadMacLayout: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar
            MainNavigationBar(
                viewModel: viewModel.navigationViewModel,
                onTabSelected: { tab in
                    viewModel.selectTab(tab)
                }
            )

            // Content Area
            NavigationStack {
                ZStack {
                    switch viewModel.selectedTab {
                    case .dashboard:
                        DashboardView()
                    case .tasks:
                        AllTasksView(workspaceId: viewModel.selectedWorkspaceId)
                    case .projects:
                        WorkspaceProjectsView(workspaceId: viewModel.selectedWorkspaceId)
                    case .messages:
                        WorkspaceMessagesView(workspaceId: viewModel.selectedWorkspaceId)
                    case .settings:
                        SettingsView()
                    }
                }
            }
        }
    }
}

// MARK: - Workspace Projects View
struct WorkspaceProjectsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkspaceProjectsViewModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedProject: Project?
    @State private var showingCreateProject = false
    @State private var searchText = ""

    let workspaceId: String?

    init(workspaceId: String? = nil) {
        self.workspaceId = workspaceId
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                projectsContent(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = WorkspaceProjectsViewModel(modelContext: modelContext, workspaceId: workspaceId)
                    }
            }
        }
    }

    @ViewBuilder
    private func projectsContent(viewModel: WorkspaceProjectsViewModel) -> some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            projectsToolbar(viewModel: viewModel)

            // Content
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.filteredProjects.isEmpty {
                    emptyState(viewModel: viewModel)
                } else {
                    projectsGrid(viewModel: viewModel)
                }
            }
        }
        .background(TaskFlowColors.background)
        .navigationTitle("Projects")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingCreateProject = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(TaskFlowColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            if let wsId = workspaceId {
                // If we have a workspace ID, use the repository-based creation
                // Fetch workspace first
                let ws = try? modelContext.fetch(FetchDescriptor<Workspace>(predicate: #Predicate { $0.id == wsId })).first
                if let workspace = ws {
                    CreateProjectView(viewModel: WorkspaceDetailViewModel(workspace: workspace, modelContext: modelContext)) { project in
                        showingCreateProject = false
                        viewModel.loadProjects()
                    }
                }
            } else {
                // Fallback or generic creation
                CreateProjectSheet { project in
                    showingCreateProject = false
                    viewModel.loadProjects()
                }
            }
        }
        .task {
            viewModel.loadProjects()
        }
#if os(iOS)
        .refreshable {
            viewModel.loadProjects()
        }
#endif
        .navigationDestination(item: $selectedProject) { project in
            ProjectDetailView(project: project)
        }
    }

    // MARK: - Toolbar
    private func projectsToolbar(viewModel: WorkspaceProjectsViewModel) -> some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(TaskFlowColors.textTertiary)

            TextField("Search projects...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _, newValue in
                    viewModel.searchText = newValue
                    viewModel.applyFilters()
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.searchText = ""
                    viewModel.applyFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
        }
        .padding(TaskFlowSpacing.medium)
        .liquidGlass(style: .thin, cornerRadius: 16)
        .padding()
    }

    // MARK: - Empty State
    private func emptyState(viewModel: WorkspaceProjectsViewModel) -> some View {
        VStack(spacing: TaskFlowSpacing.large) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)

            Text(viewModel.searchText.isEmpty ? "No Projects Yet" : "No Matching Projects")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            Text(viewModel.searchText.isEmpty
                 ? "Create your first project to get started"
                 : "Try a different search term")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Projects Grid
    private func projectsGrid(viewModel: WorkspaceProjectsViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: TaskFlowSpacing.large) {
                ForEach(viewModel.filteredProjects, id: \.id) { project in
                    ProjectCard(project: project)
                        .onTapGesture {
                            selectedProject = project
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - Workspace Projects View Model
@MainActor
class WorkspaceProjectsViewModel: ObservableObject {
    @Published var projects: [Project] = []
    @Published var filteredProjects: [Project] = []
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let modelContext: ModelContext
    private let workspaceId: String?

    init(
        modelContext: ModelContext,
        workspaceId: String? = nil
    ) {
        self.modelContext = modelContext
        self.workspaceId = workspaceId
    }

    func loadProjects() {
        isLoading = true

        do {
            var descriptor: FetchDescriptor<Project>

            // Filter by workspace if specified
            if let workspaceId = workspaceId {
                descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { $0.workspace?.id == workspaceId && !$0.isArchived },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            } else {
                descriptor = FetchDescriptor<Project>(
                    predicate: #Predicate { !$0.isArchived },
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
            }

            projects = try modelContext.fetch(descriptor)
            applyFilters()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func applyFilters() {
        if searchText.isEmpty {
            filteredProjects = projects
        } else {
            filteredProjects = projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.projectDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

// MARK: - Create Project Sheet
struct CreateProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#6366F1"
    @State private var selectedIcon = "folder.fill"
    @State private var isLoading = false

    let icons = ["folder.fill", "star.fill", "bolt.fill", "heart.fill", "flame.fill", "target", "globe", "sparkles"]
    let colors = ["#6366F1", "#F43F5E", "#10B981", "#F59E0B", "#8B5CF6", "#06B6D4", "#EC4899", "#64748B"]

    var onSave: (Project) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TaskFlowSpacing.large) {
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
                    .liquidGlass(style: .regular, cornerRadius: 24)
                    
                    VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                        Text("Appearance")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(TaskFlowColors.textPrimary)

                        TFColorPicker(selectedColor: $selectedColor, colors: colors, columns: 8)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TaskFlowSpacing.medium), count: 8), spacing: TaskFlowSpacing.medium) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.15) : Color.primary.opacity(0.05))
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
                    .liquidGlass(style: .regular, cornerRadius: 24)
                }
                .padding()
            }
            .background(TaskFlowColors.background.ignoresSafeArea())
            .navigationTitle("New Project")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    TFButton(title: "Create", style: .primary, size: .small, isLoading: isLoading) {
                        createProject()
                    }
                    .disabled(name.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func createProject() {
        guard !name.isEmpty else { return }

        isLoading = true

        do {
            let project = Project(
                name: name,
                projectDescription: description.isEmpty ? nil : description,
                color: selectedColor,
                icon: selectedIcon
            )
            
            // Initialize default columns as in repository
            project.boardColumns = [
                BoardColumn(name: "To Do", color: "#F43F5E", order: 0),
                BoardColumn(name: "In Progress", color: "#F59E0B", order: 1),
                BoardColumn(name: "Review", color: "#06B6D4", order: 2),
                BoardColumn(name: "Done", color: "#10B981", order: 3)
            ]

            modelContext.insert(project)
            try modelContext.save()

            onSave(project)
            dismiss()
        } catch {
            print("Error creating project: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview("Main App (iPhone)") {
    MainAppView()
}

#Preview("Main App (iPad)") {
    MainAppView()
        .environment(\.horizontalSizeClass, .regular)
}
