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

    @State private var selectedTask: Task?
    @State private var selectedProject: Project?
    @State private var selectedWorkspace: Workspace?

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
        VStack(spacing: 0) {
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

            // Bottom Navigation Bar
            MainNavigationBar(
                viewModel: viewModel.navigationViewModel,
                onTabSelected: { tab in
                    viewModel.selectTab(tab)
                }
            )
        }
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

            Divider()
                .foregroundColor(TaskFlowColors.border)

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
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingCreateProject = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(TaskFlowColors.primary)
                }
            }
        }
        .sheet(isPresented: $showingCreateProject) {
            CreateProjectSheet { project in
                showingCreateProject = false
                viewModel.loadProjects()
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
        .task {
            viewModel.loadProjects()
        }
#if os(iOS)
        .refreshable {
            viewModel.loadProjects()
        }
#endif
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
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
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
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: TaskFlowSpacing.large) {
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
            var descriptor = FetchDescriptor<Project>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )

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
    @State private var selectedColor = "#4ECDC4"
    @State private var selectedIcon = "folder.fill"
    @State private var isLoading = false

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
                        errorMessage: name.isEmpty ? "Name is required" : nil
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

                                    if selectedIcon == icon {
                                        Circle()
                                            .stroke(TaskFlowColors.primary, lineWidth: 2)
                                            .frame(width: 44, height: 44)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
            }
            .navigationTitle("New Project")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
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
