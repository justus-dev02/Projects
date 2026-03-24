//
//  WorkspaceListView.swift
//  Projects
//
//  TaskFlow - Workspace List View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Workspace List View Model
@MainActor
class WorkspaceListViewModel: ObservableObject {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]

    @Published var searchText = ""
    @Published var showingCreateWorkspace = false
    @Published var selectedWorkspace: Workspace?
    @Published var errorMessage: String?

    private let workspaceRepo: WorkspaceRepository
    private let authService: AuthService
    private let dataService: DataService

    init(
        modelContext: ModelContext? = nil,
        dataService: DataService? = nil,
        workspaceRepo: WorkspaceRepository? = nil,
        authService: AuthService? = nil
    ) {
        let context = modelContext ?? DataService().modelContext
        self.dataService = dataService ?? DataService(modelContext: context)
        self.workspaceRepo = workspaceRepo ?? WorkspaceRepository(dataService: self.dataService)
        self.authService = authService ?? AuthService(modelContext: context)
    }
    
    var filteredWorkspaces: [Workspace] {
        if searchText.isEmpty {
            return workspaces.filter { !$0.isArchived }
        } else {
            return workspaces.filter {
                !$0.isArchived &&
                ($0.name.localizedCaseInsensitiveContains(searchText) ||
                 ($0.workspaceDescription?.localizedCaseInsensitiveContains(searchText) ?? false))
            }
        }
    }

    func createWorkspace(name: String, workspaceDescription: String?, color: String, icon: String) throws {
        // Get or create local user
        var user = authService.currentUser

        if user == nil {
            // Create local user if none exists
            let localUser = User(
                email: "local@taskflow.dev",
                displayName: "Local User",
                role: "owner",
                isLocalUser: true
            )
            dataService.insert(localUser)
            try dataService.save()
            user = localUser
        }

        guard let user = user else {
            throw NSError(domain: "Not authenticated", code: 401)
        }

        _ = try workspaceRepo.createWorkspace(
            name: name,
            workspaceDescription: workspaceDescription,
            color: color,
            icon: icon,
            owner: user
        )
    }
    
    func deleteWorkspace(_ workspace: Workspace) throws {
        try workspaceRepo.deleteWorkspace(workspace)
    }
    
    func archiveWorkspace(_ workspace: Workspace) throws {
        try workspaceRepo.archiveWorkspace(workspace)
    }
}

// MARK: - Workspace List View
struct WorkspaceListView: View {
    @StateObject private var viewModel = WorkspaceListViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    // iPad/Mac - Grid layout
                    workspaceGrid
                } else {
                    // iPhone - List layout
                    workspaceList
                }
            }
            .navigationTitle("Workspaces")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .searchable(text: $viewModel.searchText, prompt: "Search workspaces")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    TFButton(title: "New", style: .primary, size: .small, icon: "plus") {
                        showingCreateSheet = true
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateWorkspaceView { workspace in
                    viewModel.selectedWorkspace = workspace
                    showingCreateSheet = false
                }
            }
        }
    }
    
    // MARK: - Workspace Grid
    private var workspaceGrid: some View {
        ScrollView {
            if viewModel.filteredWorkspaces.isEmpty {
                TFEmptyStateCard(
                    icon: "briefcase",
                    title: viewModel.searchText.isEmpty ? "No Workspaces" : "No Results",
                    message: viewModel.searchText.isEmpty
                        ? "Create your first workspace to organize your projects."
                        : "Try a different search term.",
                    actionTitle: viewModel.searchText.isEmpty ? "Create Workspace" : nil,
                    action: {
                        showingCreateSheet = true
                    }
                )
                .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TaskFlowSpacing.large) {
                    ForEach(viewModel.filteredWorkspaces, id: \.id) { workspace in
                        WorkspaceGridCard(workspace: workspace)
                            .onTapGesture {
                                viewModel.selectedWorkspace = workspace
                            }
                    }
                }
                .padding()
            }
        }
        .background(TaskFlowColors.background)
    }
    
    // MARK: - Workspace List
    private var workspaceList: some View {
        ScrollView {
            LazyVStack(spacing: TaskFlowSpacing.large) {
                ForEach(viewModel.filteredWorkspaces, id: \.id) { workspace in
                    NavigationLink(destination: WorkspaceDetailView(workspace: workspace)) {
                        WorkspaceListRow(workspace: workspace)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .background(TaskFlowColors.background)
    }
}

    // MARK: - Workspace Grid Card
struct WorkspaceGridCard: View {
    let workspace: Workspace
    
    var body: some View {
        NavigationLink(destination: WorkspaceDetailView(workspace: workspace)) {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: workspace.color).opacity(0.12))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: workspace.icon)
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: workspace.color))
                    }
                    
                    Spacer()
                    
                    // Owner Badge
                    TFAvatar(name: workspace.owner?.displayName ?? "U", colorHex: workspace.owner?.avatarColor ?? workspace.color, size: .small)
                }
                
                // Info
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                    Text(workspace.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .lineLimit(1)
                    
                    if let workspaceDescription = workspace.workspaceDescription {
                        Text(workspaceDescription)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TaskFlowColors.textSecondary)
                            .lineLimit(2)
                            .frame(height: 32, alignment: .top)
                    }
                }
                
                Spacer(minLength: 0)
                
                // Stats
                HStack(spacing: TaskFlowSpacing.medium) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                        Text("\(workspace.projectCount)")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(TaskFlowColors.primary.opacity(0.08))
                    .cornerRadius(8)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("\(workspace.memberCount)")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(TaskFlowColors.success.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding(TaskFlowSpacing.xLarge)
            .liquidGlass(style: .regular, cornerRadius: 28, tint: Color(hex: workspace.color).opacity(0.05))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workspace List Row
struct WorkspaceListRow: View {
    let workspace: Workspace
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: workspace.color).opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: workspace.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: workspace.color))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                Text("\(workspace.projectCount) Projects • \(workspace.memberCount) Members")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(TaskFlowColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(TaskFlowColors.textTertiary)
        }
        .padding(TaskFlowSpacing.large)
        .liquidGlass(style: .ultra, cornerRadius: 20, tint: Color(hex: workspace.color).opacity(0.03))
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
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

// MARK: - Create Workspace View
struct CreateWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#6366F1"
    @State private var selectedIcon = "briefcase.fill"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let icons = ["briefcase.fill", "building.2.fill", "globe", "sparkles", "star.fill", "heart.fill", "flame.fill", "bolt.fill"]
    let colors = ["#6366F1", "#F43F5E", "#10B981", "#F59E0B", "#8B5CF6", "#06B6D4", "#EC4899", "#64748B"]

    var onSave: (Workspace) -> Void

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
                        .background(TaskFlowColors.error.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: TaskFlowSpacing.large) {
                        // Basic Info Section
                        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                            TFTextField(
                                title: "Name",
                                placeholder: "Enter workspace name",
                                text: $name
                            )
                            
                            TFTextField(
                                title: "Description (Optional)",
                                placeholder: "Describe your workspace",
                                text: $description,
                                multiline: true,
                                minLineCount: 3
                            )
                        }
                        .padding()
                        .liquidGlass(style: .regular, cornerRadius: 24)

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
                                                .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.15) : Color.primary.opacity(0.05))
                                                .frame(width: 44, height: 44)

                                            Image(systemName: icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : TaskFlowColors.textSecondary)
                                            
                                            if selectedIcon == icon {
                                                Circle()
                                                    .stroke(Color(hex: selectedColor), lineWidth: 2)
                                                    .frame(width: 44, height: 44)
                                            }
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
            }
            .background(TaskFlowColors.background.ignoresSafeArea())
            .navigationTitle("New Workspace")
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
                        createWorkspace()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func createWorkspace() {
        guard !name.isEmpty else {
            errorMessage = "Name is required"
            return
        }

        isLoading = true

        do {
            // Get or create local user
            let predicate = #Predicate<User> { $0.isLocalUser == true }
            var user: User?

            user = try modelContext.fetch(FetchDescriptor<User>(predicate: predicate)).first

            if user == nil {
                user = User(
                    email: "local@taskflow.dev",
                    displayName: "Local User",
                    role: "owner",
                    isLocalUser: true
                )
                modelContext.insert(user!)
                try modelContext.save()
            }

            // Create workspace
            let workspace = Workspace(
                name: name,
                workspaceDescription: description.isEmpty ? nil : description,
                color: selectedColor,
                icon: selectedIcon
            )
            workspace.owner = user

            // Create workspace member for owner
            let member = WorkspaceMember(role: "owner")
            member.user = user
            workspace.members?.append(member)

            modelContext.insert(workspace)
            try modelContext.save()

            onSave(workspace)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            print("Error creating workspace: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Preview
#Preview("Workspace List") {
    WorkspaceListView()
}

#Preview("Create Workspace") {
    CreateWorkspaceView(onSave: { _ in })
}

