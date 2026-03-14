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
        List {
            ForEach(viewModel.filteredWorkspaces, id: \.id) { workspace in
                WorkspaceListRow(workspace: workspace)
                    .onTapGesture {
                        viewModel.selectedWorkspace = workspace
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            try? viewModel.deleteWorkspace(workspace)
                        } label: {
                            SwiftUI.Label("Delete", systemImage: "trash")
                        }

                        Button {
                            try? viewModel.archiveWorkspace(workspace)
                        } label: {
                            SwiftUI.Label("Archive", systemImage: "archivebox")
                        }
                        .tint(TaskFlowColors.warning)
                    }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#elseif os(macOS)
        .listStyle(.inset)
#endif
    }
}

// MARK: - Workspace Grid Card
struct WorkspaceGridCard: View {
    let workspace: Workspace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationLink(destination: WorkspaceDetailView(workspace: workspace)) {
            TFCard(
                padding: TaskFlowSpacing.xLarge,
                backgroundColor: .white
            ) {
                VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: workspace.color).opacity(0.1))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: workspace.icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: workspace.color))
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                        Text(workspace.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(TaskFlowColors.textPrimary)
                            .lineLimit(1)
                        
                        if let workspaceDescription = workspace.workspaceDescription {
                            Text(workspaceDescription)
                                .font(.system(size: 13))
                                .foregroundColor(TaskFlowColors.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Stats
                    HStack(spacing: TaskFlowSpacing.large) {
                        StatBadge(
                            value: "\(workspace.projectCount)",
                            label: "Projects",
                            icon: "folder.fill"
                        )
                        
                        StatBadge(
                            value: "\(workspace.memberCount)",
                            label: "Members",
                            icon: "person.2.fill"
                        )
                        
                        Spacer()
                    }
                }
            }
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
                    .fill(Color(hex: workspace.color).opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: workspace.icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: workspace.color))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                Text("\(workspace.projectCount) Projects • \(workspace.memberCount) Members")
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textTertiary)
        }
        .padding(.vertical, TaskFlowSpacing.small)
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
    @State private var selectedColor = "#2D5BFF"
    @State private var selectedIcon = "briefcase.fill"
    @State private var isLoading = false
    @State private var errorMessage: String?

    let icons = ["briefcase.fill", "building.2.fill", "globe", "sparkles", "star.fill", "heart.fill", "flame.fill", "bolt.fill"]
    let colors = ["#2D5BFF", "#FF6B6B", "#00BA88", "#FFB020", "#A855F7", "#4ECDC4", "#45B7D1", "#FF4757"]

    var onSave: (Workspace) -> Void

    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TFTextField(
                        title: "Name",
                        placeholder: "Enter workspace name",
                        text: $name,
                        errorMessage: name.isEmpty && errorMessage != nil ? "Name is required" : nil
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }

                // Description Section
                Section {
                    TFTextField(
                        title: "Description (Optional)",
                        placeholder: "Describe your workspace",
                        text: $description,
                        multiline: true,
                        minLineCount: 3
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }

                // Color Section
                Section {
                    Text("Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    TFColorPicker(selectedColor: $selectedColor, colors: colors, columns: 8)
                        .padding(.vertical, TaskFlowSpacing.medium)
                }

                // Icon Section
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
            .navigationTitle("New Workspace")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createWorkspace()
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

