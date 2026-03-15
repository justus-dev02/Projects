//
//  WorkspaceSettingsView.swift
//  Projects
//
//  TaskFlow - Workspace Settings View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Workspace Settings View Model
@MainActor
class WorkspaceSettingsViewModel: ObservableObject {
    @Published var workspace: Workspace?
    @Published var members: [WorkspaceMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingInviteSheet = false
    @Published var showingDeleteConfirm = false
    @Published var showingArchiveConfirm = false

    // Editable properties
    @Published var name: String = ""
    @Published var workspaceDescription: String = ""
    @Published var color: String = ""
    @Published var icon: String = ""

    private let modelContext: ModelContext
    private let workspaceRepo: WorkspaceRepository
    private let authService: AuthService

    init(
        modelContext: ModelContext,
        workspaceId: String? = nil,
        workspaceRepo: WorkspaceRepository? = nil,
        authService: AuthService? = nil
    ) {
        self.modelContext = modelContext
        self.workspaceRepo = workspaceRepo ?? WorkspaceRepository(dataService: DataService(modelContext: modelContext))
        self.authService = authService ?? AuthService(modelContext: modelContext)

        if let workspaceId = workspaceId {
            loadWorkspace(workspaceId: workspaceId)
        }
    }

    func loadWorkspace(workspaceId: String) {
        isLoading = true

        do {
            let descriptor = FetchDescriptor<Workspace>(
                predicate: #Predicate { $0.id == workspaceId }
            )
            workspace = try modelContext.fetch(descriptor).first

            if let ws = workspace {
                name = ws.name
                workspaceDescription = ws.workspaceDescription ?? ""
                color = ws.color
                icon = ws.icon
            }

            loadMembers()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadMembers() {
        do {
            let descriptor = FetchDescriptor<WorkspaceMember>(
                sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
            )
            members = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveChanges() throws {
        guard let workspace = workspace else {
            throw NSError(domain: "No workspace", code: 404)
        }

        workspace.name = name
        workspace.workspaceDescription = workspaceDescription.isEmpty ? nil : workspaceDescription
        workspace.color = color
        workspace.icon = icon
        workspace.updatedAt = Date()

        try modelContext.save()
    }

    func updateMemberRole(_ member: WorkspaceMember, newRole: String) throws {
        member.role = newRole
        try modelContext.save()
    }

    func removeMember(_ member: WorkspaceMember) throws {
        guard let currentUser = authService.currentUser else {
            throw NSError(domain: "Not authenticated", code: 401)
        }

        // Prevent removing yourself
        if member.user?.id == currentUser.id {
            throw NSError(domain: "Cannot remove yourself", code: 400)
        }

        modelContext.delete(member)
        try modelContext.save()
        members.removeAll { $0.id == member.id }
    }

    func archiveWorkspace() throws {
        guard let workspace = workspace else { return }
        try workspaceRepo.archiveWorkspace(workspace)
    }

    func deleteWorkspace() throws {
        guard let workspace = workspace else { return }
        try workspaceRepo.deleteWorkspace(workspace)
    }

    func generateInviteLink() -> String {
        // Generate a mock invite link
        guard let workspace = workspace else { return "" }
        return "taskflow://invite/\(workspace.id)/\(UUID().uuidString.prefix(8))"
    }

    var canEditSettings: Bool {
        guard let currentUser = authService.currentUser,
              let workspace = workspace else { return false }

        guard let member = members.first(where: { $0.user?.id == currentUser.id }) else {
            return false
        }

        return ["owner", "admin"].contains(member.role.lowercased())
    }

    var isOwner: Bool {
        guard let currentUser = authService.currentUser,
              let workspace = workspace else { return false }

        return workspace.owner?.id == currentUser.id
    }
}

// MARK: - Workspace Settings View
struct WorkspaceSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkspaceSettingsViewModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showingInviteSheet = false
    @State private var showingDeleteConfirm = false
    @State private var selectedIcon: String = ""
    @State private var selectedColor: String = ""

    let workspaceId: String?

    init(workspaceId: String? = nil) {
        self.workspaceId = workspaceId
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                settingsForm(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = WorkspaceSettingsViewModel(modelContext: modelContext, workspaceId: workspaceId)
                    }
            }
        }
        .navigationTitle("Workspace Settings")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            if let vm = viewModel {
                InviteMembersView(viewModel: vm)
            }
        }
        .alert("Delete Workspace", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                try? viewModel?.deleteWorkspace()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this workspace? This action cannot be undone and all projects and tasks will be deleted.")
        }
    }

    // MARK: - Settings Form
    @ViewBuilder
    private func settingsForm(viewModel: WorkspaceSettingsViewModel) -> some View {
        Form {
            // Profile Section
            Section {
                profileSection(viewModel: viewModel)
            } header: {
                Text("Profile")
            }

            // Appearance Section
            Section {
                appearanceSection(viewModel: viewModel)
            } header: {
                Text("Appearance")
            }

            // Members Section
            Section {
                membersSection(viewModel: viewModel)
            } header: {
                HStack {
                    Text("Members")
                    Spacer()
                    Button {
                        showingInviteSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(TaskFlowColors.primary)
                    }
                }
            }

            // Danger Zone
            if viewModel.canEditSettings {
                Section {
                    dangerZoneSection(viewModel: viewModel)
                } header: {
                    Text("Danger Zone")
                }
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#endif
    }

    // MARK: - Profile Section
    private func profileSection(viewModel: WorkspaceSettingsViewModel) -> some View {
        VStack(spacing: TaskFlowSpacing.large) {
            // Workspace Icon Preview
            ZStack {
                Circle()
                    .fill(Color(hex: viewModel.color).opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: viewModel.icon)
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: viewModel.color))
            }

            // Name Field
            TFTextField(
                title: "Workspace Name",
                text: Binding(get: { viewModel.name }, set: { viewModel.name = $0 }),
                errorMessage: viewModel.name.isEmpty ? "Name is required" : nil
            )

            // Description Field
            TFTextField(
                title: "Description",
                placeholder: "Describe your workspace",
                text: Binding(get: { viewModel.workspaceDescription }, set: { viewModel.workspaceDescription = $0 }),
                multiline: true,
                minLineCount: 3
            )
        }
        .padding(.vertical, TaskFlowSpacing.large)
    }

    // MARK: - Appearance Section
    private func appearanceSection(viewModel: WorkspaceSettingsViewModel) -> some View {
        VStack(spacing: TaskFlowSpacing.large) {
            // Color Picker
            VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
                Text("Color")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)

                TFColorPicker(
                    selectedColor: Binding(get: { viewModel.color }, set: { viewModel.color = $0 }),
                    colors: [
                        "#2D5BFF", "#FF6B6B", "#00BA88", "#FFB020",
                        "#A855F7", "#4ECDC4", "#45B7D1", "#FF4757"
                    ],
                    columns: 8
                )
            }
            .padding(.vertical, TaskFlowSpacing.small)

            // Icon Picker
            VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
                Text("Icon")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: TaskFlowSpacing.medium), count: 8), spacing: TaskFlowSpacing.medium) {
                    let icons = ["briefcase.fill", "building.2.fill", "globe", "sparkles", "star.fill", "heart.fill", "flame.fill", "bolt.fill"]
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            viewModel.icon = icon
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(viewModel.icon == icon ? TaskFlowColors.primary.opacity(0.1) : TaskFlowColors.background)
                                    .frame(width: 44, height: 44)

                                Image(systemName: icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(viewModel.icon == icon ? TaskFlowColors.primary : TaskFlowColors.textSecondary)

                                if viewModel.icon == icon {
                                    Circle()
                                        .stroke(TaskFlowColors.primary, lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, TaskFlowSpacing.small)
        }
    }

    // MARK: - Members Section
    private func membersSection(viewModel: WorkspaceSettingsViewModel) -> some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            ForEach(viewModel.members, id: \.id) { member in
                MemberRow(
                    member: member,
                    isOwner: viewModel.isOwner,
                    canEdit: viewModel.canEditSettings,
                    onRoleChange: { newRole in
                        try? viewModel.updateMemberRole(member, newRole: newRole)
                    },
                    onRemove: {
                        try? viewModel.removeMember(member)
                    }
                )
            }
        }
        .padding(.vertical, TaskFlowSpacing.small)
    }

    // MARK: - Danger Zone Section
    private func dangerZoneSection(viewModel: WorkspaceSettingsViewModel) -> some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Button(role: .destructive) {
                viewModel.showingArchiveConfirm = true
            } label: {
                HStack {
                    SwiftUI.Label("Archive Workspace", systemImage: "archivebox")
                    Spacer()
                }
            }

            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    SwiftUI.Label("Delete Workspace", systemImage: "trash")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Member Row
struct MemberRow: View {
    let member: WorkspaceMember
    let isOwner: Bool
    let canEdit: Bool
    let onRoleChange: (String) -> Void
    let onRemove: () -> Void

    @State private var showingRolePicker = false
    @State private var showingRemoveConfirm = false

    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            if let user = member.user {
                TFAvatar(name: user.displayName, colorHex: user.avatarColor, size: .medium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    HStack(spacing: TaskFlowSpacing.small) {
                        Text(memberRoleText(member.role))
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textTertiary)

                        if member.role.lowercased() == "owner" {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(TaskFlowColors.warning)
                        }
                    }
                }

                Spacer()

                // Role Picker (for admins/owners)
                if canEdit && !isOwner {
                    Menu {
                        ForEach(["owner", "admin", "member", "guest", "viewer"], id: \.self) { role in
                            Button(action: {
                                onRoleChange(role)
                            }) {
                                HStack {
                                    Text(memberRoleText(role))
                                    if member.role.lowercased() == role {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .disabled(role == "owner") // Only transfer ownership through special flow
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                }

                // Remove Button (for owners/admins)
                if canEdit && !isOwner && member.role.lowercased() != "owner" {
                    Button(action: {
                        showingRemoveConfirm = true
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(TaskFlowColors.error)
                    }
                }
            }
        }
        .padding(.vertical, TaskFlowSpacing.small)
        .confirmationDialog("Remove Member", isPresented: $showingRemoveConfirm) {
            Button("Remove", role: .destructive) {
                onRemove()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this member from the workspace?")
        }
    }

    private func memberRoleText(_ role: String) -> String {
        switch role.lowercased() {
        case "owner": return "Owner"
        case "admin": return "Admin"
        case "member": return "Member"
        case "guest": return "Guest"
        case "viewer": return "Viewer"
        default: return "Member"
        }
    }
}

// MARK: - Invite Members View
struct InviteMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkspaceSettingsViewModel

    @State private var inviteLink = ""
    @State private var hasGeneratedLink = false
    @State private var emailAddresses = ""

    var body: some View {
        NavigationStack {
            Form {
                // Generate Link Section
                Section {
                    if !hasGeneratedLink {
                        Button(action: {
                            inviteLink = viewModel.generateInviteLink()
                            hasGeneratedLink = true
                        }) {
                            HStack {
                                SwiftUI.Label("Generate Invite Link", systemImage: "link.badge.plus")
                                    .foregroundColor(TaskFlowColors.textPrimary)
                                Spacer()
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
                            Text("Invite Link")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(TaskFlowColors.textPrimary)

                            HStack {
                                Text(inviteLink)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(TaskFlowColors.primary)
                                    .lineLimit(1)

                                Spacer()

                                Button(action: {
                                    // Copy to clipboard
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(TaskFlowColors.primary)
                                }
                            }
                            .padding(TaskFlowSpacing.small)
                            .background(TaskFlowColors.background)
                            .cornerRadius(TaskFlowRadius.small)
                        }
                    }
                } header: {
                    Text("Invite Link")
                } footer: {
                    Text("Share this link with team members to invite them to the workspace")
                }

                // Email Invite Section
                Section {
                    TFTextField(
                        title: "Email Addresses",
                        placeholder: "email1@example.com, email2@example.com",
                        text: $emailAddresses,
                        multiline: true,
                        minLineCount: 3
                    )

                    Button(action: {
                        // Send email invites
                    }) {
                        HStack {
                            SwiftUI.Label("Send Email Invites", systemImage: "envelope.fill")
                                .foregroundColor(TaskFlowColors.primary)
                            Spacer()
                        }
                    }
                    .disabled(emailAddresses.isEmpty)
                } header: {
                    Text("Email Invites")
                } footer: {
                    Text("Enter email addresses separated by commas")
                }
            }
            .navigationTitle("Invite Members")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Workspace Settings") {
    NavigationStack {
        WorkspaceSettingsView()
    }
}

