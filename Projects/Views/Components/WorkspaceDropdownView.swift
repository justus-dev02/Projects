//
//  WorkspaceDropdownView.swift
//  Projects
//
//  TaskFlow - Workspace Dropdown Menu Component
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Workspace Dropdown View Model
@MainActor
class WorkspaceDropdownViewModel: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspace: Workspace?
    @Published var showingCreateWorkspace = false
    @Published var showingJoinWorkspace = false
    @Published var joinLink = ""
    @Published var errorMessage: String?

    private var modelContext: ModelContext
    private let authService: AuthService

    init(modelContext: ModelContext, authService: AuthService? = nil) {
        self.modelContext = modelContext
        self.authService = authService ?? AuthService(modelContext: modelContext)
        loadWorkspaces()
    }

    func loadWorkspaces() {
        do {
            let descriptor = FetchDescriptor<Workspace>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            workspaces = try modelContext.fetch(descriptor).filter { !$0.isArchived }
            
            if selectedWorkspace == nil && !workspaces.isEmpty {
                selectedWorkspace = workspaces.first
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectWorkspace(_ workspace: Workspace) {
        selectedWorkspace = workspace
    }

    func createWorkspace(name: String, description: String?, color: String, icon: String) throws -> Workspace {
        guard let user = authService.currentUser else {
            throw NSError(domain: "Not authenticated", code: 401)
        }

        let workspace = Workspace(
            name: name,
            workspaceDescription: description,
            color: color,
            icon: icon
        )
        workspace.owner = user

        let member = WorkspaceMember(role: "owner")
        member.user = user
        workspace.members?.append(member)

        modelContext.insert(workspace)
        try modelContext.save()

        workspaces.insert(workspace, at: 0)
        selectedWorkspace = workspace

        return workspace
    }

    func joinWorkspace(with link: String) throws {
        print("Joining workspace with link: \(link)")
    }
}

// MARK: - Workspace Dropdown View
struct WorkspaceDropdownView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkspaceDropdownViewModel?

    @Binding var selectedWorkspaceId: String?
    var onWorkspaceSelected: ((Workspace) -> Void)?

    init(selectedWorkspaceId: Binding<String?>, onWorkspaceSelected: ((Workspace) -> Void)? = nil) {
        _selectedWorkspaceId = selectedWorkspaceId
        self.onWorkspaceSelected = onWorkspaceSelected
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                dropdownContent(viewModel: vm)
            } else {
                dropdownLabel
                    .onAppear {
                        viewModel = WorkspaceDropdownViewModel(modelContext: modelContext)
                    }
            }
        }
    }

    @ViewBuilder
    private func dropdownContent(viewModel: WorkspaceDropdownViewModel) -> some View {
        Menu {
            Button {
                viewModel.showingCreateWorkspace = true
            } label: {
                SwiftUI.Label("New Workspace", systemImage: "plus.circle.fill")
            }

            Button {
                viewModel.showingJoinWorkspace = true
            } label: {
                SwiftUI.Label("Join Workspace", systemImage: "person.badge.plus")
            }

            Divider()

            if viewModel.workspaces.isEmpty {
                Text("No workspaces yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.workspaces, id: \.id) { workspace in
                    Button {
                        selectWorkspace(workspace, viewModel: viewModel)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: workspace.color))
                                .frame(width: 10, height: 10)

                            Text(workspace.name)
                                .lineLimit(1)

                            if viewModel.selectedWorkspace?.id == workspace.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10))
                            }
                        }
                    }
                }
            }
        } label: {
            dropdownLabel
        }
        .sheet(isPresented: Binding(get: { viewModel.showingCreateWorkspace }, set: { viewModel.showingCreateWorkspace = $0 })) {
            CreateWorkspaceDropdownView { workspace in
                viewModel.showingCreateWorkspace = false
                selectWorkspace(workspace, viewModel: viewModel)
            }
        }
        .sheet(isPresented: Binding(get: { viewModel.showingJoinWorkspace }, set: { viewModel.showingJoinWorkspace = $0 })) {
            JoinWorkspaceDropdownView { link in
                try? viewModel.joinWorkspace(with: link)
                viewModel.showingJoinWorkspace = false
            }
        }
    }

    private var dropdownLabel: some View {
        HStack(spacing: TaskFlowSpacing.small) {
            if let workspace = viewModel?.selectedWorkspace {
                ZStack {
                    Circle()
                        .fill(Color(hex: workspace.color).opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: workspace.icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: workspace.color))
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(workspace.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .lineLimit(1)

                    Text("Workspace")
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Select Workspace")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    Text("No workspace")
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 10))
                .foregroundColor(TaskFlowColors.textTertiary)
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

    private func selectWorkspace(_ workspace: Workspace, viewModel: WorkspaceDropdownViewModel) {
        viewModel.selectWorkspace(workspace)
        selectedWorkspaceId = workspace.id
        onWorkspaceSelected?(workspace)
    }
}

// MARK: - Create Workspace Dropdown View
struct CreateWorkspaceDropdownView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var description = ""
    @State private var selectedColor = "#2D5BFF"
    @State private var selectedIcon = "briefcase.fill"
    @State private var isLoading = false

    let icons = ["briefcase.fill", "building.2.fill", "globe", "sparkles", "star.fill", "heart.fill", "flame.fill", "bolt.fill"]
    let colors = ["#2D5BFF", "#FF6B6B", "#00BA88", "#FFB020", "#A855F7", "#4ECDC4", "#45B7D1", "#FF4757"]

    var onSave: (Workspace) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TFTextField(
                        title: "Name",
                        placeholder: "Enter workspace name",
                        text: $name,
                        errorMessage: name.isEmpty ? "Name is required" : nil
                    )
                    .padding(.vertical, TaskFlowSpacing.medium)
                }

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
                            Button {
                                selectedIcon = icon
                            } label: {
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
        guard !name.isEmpty else { return }

        isLoading = true

        do {
            let workspace = Workspace(
                name: name,
                workspaceDescription: description.isEmpty ? nil : description,
                color: selectedColor,
                icon: selectedIcon
            )

            let predicate = #Predicate<User> { $0.isLocalUser == true }
            var user: User? = try modelContext.fetch(FetchDescriptor<User>(predicate: predicate)).first

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

            workspace.owner = user

            let member = WorkspaceMember(role: "owner")
            member.user = user
            workspace.members?.append(member)

            modelContext.insert(workspace)
            try modelContext.save()

            onSave(workspace)
            dismiss()
        } catch {
            print("Error creating workspace: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Join Workspace Dropdown View
struct JoinWorkspaceDropdownView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteLink = ""
    @State private var isLoading = false

    var onJoin: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
                        Text("Invite Link")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TaskFlowColors.textPrimary)

                        TFTextField(
                            placeholder: "Paste your invite link here",
                            text: $inviteLink,
                            multiline: false
                        )

                        Text("Ask your workspace admin for an invite link")
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                    .padding(.vertical, TaskFlowSpacing.medium)
                }
            }
            .navigationTitle("Join Workspace")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        onJoin(inviteLink)
                    }
                    .disabled(inviteLink.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Workspace Dropdown") {
    WorkspaceDropdownView(selectedWorkspaceId: .constant(nil))
}
