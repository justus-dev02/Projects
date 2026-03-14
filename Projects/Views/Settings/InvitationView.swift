//
//  InvitationView.swift
//  Projects
//
//  TaskFlow - User Invitation Management
//

import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif
import Combine
import SwiftData

// MARK: - Invitation View
struct InvitationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: InvitationViewModel
    
    let targetType: InvitationTarget
    let targetId: String
    
    @State private var showingInviteSheet = false
    @State private var selectedInvitation: Invitation?
    @State private var showingSendEmail = false
    @State private var emailToShare: String = ""
    
    enum InvitationTarget {
        case workspace
        case project
    }
    
    init(targetType: InvitationTarget, targetId: String, dataService: DataService) {
        self.targetType = targetType
        self.targetId = targetId
        _viewModel = StateObject(wrappedValue: InvitationViewModel(dataService: dataService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Overview
                invitationStats
                
                Divider()
                
                // Invitations List
                invitationsList
            }
            .navigationTitle("Invitations")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingInviteSheet = true
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingInviteSheet) {
                CreateInvitationView(
                    targetType: targetType,
                    targetId: targetId,
                    viewModel: viewModel
                ) {
                    showingInviteSheet = false
                    viewModel.loadInvitations()
                }
            }
            .task {
                viewModel.loadInvitations()
            }
        }
    }
    
    // MARK: - Invitation Stats
    private var invitationStats: some View {
        HStack(spacing: TaskFlowSpacing.large) {
            StatBox(
                value: "\(viewModel.stats.pending)",
                label: "Pending",
                color: TaskFlowColors.warning
            )
            
            StatBox(
                value: "\(viewModel.stats.accepted)",
                label: "Accepted",
                color: TaskFlowColors.success
            )
            
            StatBox(
                value: "\(viewModel.stats.declined)",
                label: "Declined",
                color: TaskFlowColors.error
            )
            
            StatBox(
                value: "\(viewModel.stats.expired)",
                label: "Expired",
                color: TaskFlowColors.textTertiary
            )
        }
        .padding()
        .background(TaskFlowColors.background)
    }
    
    // MARK: - Invitations List
    private var invitationsList: some View {
        Group {
            if viewModel.invitations.isEmpty {
                EmptyInvitationsView {
                    showingInviteSheet = true
                }
            } else {
                List {
                    Section("Pending") {
                        ForEach(viewModel.pendingInvitations, id: \.id) { invitation in
                            InvitationRow(
                                invitation: invitation,
                                onResend: {
                                    viewModel.resendInvitation(invitation)
                                },
                                onCancel: {
                                    viewModel.cancelInvitation(invitation)
                                }
                            )
                        }
                    }
                    
                    if !viewModel.acceptedInvitations.isEmpty {
                        Section("Accepted") {
                            ForEach(viewModel.acceptedInvitations, id: \.id) { invitation in
                                InvitationRow(
                                    invitation: invitation,
                                    onResend: {},
                                    onCancel: {}
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(TaskFlowColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TaskFlowSpacing.medium)
        .background(color.opacity(0.1))
        .cornerRadius(TaskFlowRadius.medium)
    }
}

// MARK: - Invitation Row
struct InvitationRow: View {
    let invitation: Invitation
    let onResend: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(invitationStatusColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: invitationStatusIcon)
                        .font(.system(size: 16))
                        .foregroundColor(invitationStatusColor)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.email)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    HStack(spacing: TaskFlowSpacing.small) {
                        TFStatusBadge(status: invitation.status, size: .small)
                        
                        Text(invitation.expiryDescription)
                            .font(.system(size: 11))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                }
                
                Spacer()
                
                // Role badge
                TFBadge(text: invitation.role.capitalized, color: TaskFlowColors.primary, size: .small)
            }
            
            // Message
            if let message = invitation.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .lineLimit(2)
            }
            
            // Actions
            if invitation.isPending {
                HStack(spacing: TaskFlowSpacing.medium) {
                    SwiftUI.Label("Resend", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                        .onTapGesture(perform: onResend)
                    
                    SwiftUI.Label("Cancel", systemImage: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TaskFlowColors.error)
                        .onTapGesture(perform: onCancel)
                    
                    Spacer()
                    
                    // Share button
                    Button(action: {
                        // Share invitation link
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(TaskFlowColors.primary)
                    }
                }
            }
        }
        .padding(.vertical, TaskFlowSpacing.small)
    }
    
    private var invitationStatusColor: Color {
        switch invitation.status {
        case "pending": return TaskFlowColors.warning
        case "accepted": return TaskFlowColors.success
        case "declined": return TaskFlowColors.error
        case "expired", "cancelled": return TaskFlowColors.textTertiary
        default: return TaskFlowColors.primary
        }
    }
    
    private var invitationStatusIcon: String {
        switch invitation.status {
        case "pending": return "clock.fill"
        case "accepted": return "checkmark.circle.fill"
        case "declined": return "xmark.circle.fill"
        case "expired": return "exclamationmark.circle.fill"
        case "cancelled": return "slash.circle.fill"
        default: return "info.circle.fill"
        }
    }
}

// MARK: - Empty Invitations View
struct EmptyInvitationsView: View {
    let onCreateInvitation: () -> Void
    
    var body: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)
            
            Text("No Invitations")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            Text("Invite team members to collaborate\non this workspace or project")
                .font(.system(size: 13))
                .foregroundColor(TaskFlowColors.textSecondary)
                .multilineTextAlignment(.center)
            
            TFButton(title: "Invite People", style: .primary, icon: "plus") {
                onCreateInvitation()
            }
        }
        .padding(.vertical, TaskFlowSpacing.xHuge * 2)
    }
}

// MARK: - Create Invitation View
struct CreateInvitationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let targetType: InvitationView.InvitationTarget
    let targetId: String
    @ObservedObject var viewModel: InvitationViewModel
    
    let onInvitationCreated: () -> Void
    
    @State private var emails: String = ""
    @State private var selectedRole: String = "member"
    @State private var message: String = ""
    @State private var isLoading = false
    @State private var showingRolePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Emails Section
                Section {
                    Text("Enter email addresses")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    TFTextField(
                        placeholder: "email@example.com, another@example.com",
                        text: $emails,
                        multiline: true,
                        minLineCount: 3
                    )
                    
                    Text("Separate multiple emails with commas")
                        .font(.system(size: 11))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                // Role Section
                Section {
                    Button(action: {
                        showingRolePicker = true
                    }) {
                        HStack {
                            Text("Role")
                                .foregroundColor(TaskFlowColors.textPrimary)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text(selectedRole.capitalized)
                                    .foregroundColor(TaskFlowColors.textSecondary)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(TaskFlowColors.textTertiary)
                            }
                        }
                    }
                }
                
                // Message Section
                Section {
                    TFTextField(
                        title: "Personal Message (Optional)",
                        placeholder: "Add a personal note to your invitation",
                        text: $message,
                        multiline: true,
                        minLineCount: 4
                    )
                }
            }
            .navigationTitle("Invite People")
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
                        title: "Send Invites",
                        style: .primary,
                        size: .small,
                        isLoading: isLoading
                    ) {
                        sendInvitations()
                    }
                    .disabled(emails.isEmpty)
                }
            }
            .confirmationDialog("Select Role", isPresented: $showingRolePicker) {
                ForEach(["member", "admin", "viewer"], id: \.self) { role in
                    Button(role.capitalized) {
                        selectedRole = role
                    }
                }
            }
        }
    }
    
    // MARK: - Send Invitations
    private func sendInvitations() {
        isLoading = true
        
        let emailList = emails
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.contains("@") }
        
        for email in emailList {
            let invitation = Invitation(
                email: email,
                inviteType: targetType == .workspace ? "workspace" : "project",
                role: selectedRole,
                message: message.isEmpty ? nil : message
            )
            
            // Set workspace or project based on target type
            // This would be handled by the viewModel
            
            modelContext.insert(invitation)
        }
        
        do {
            try modelContext.save()
            isLoading = false
            onInvitationCreated()
            dismiss()
        } catch {
            print("Error creating invitations: \(error)")
            isLoading = false
        }
    }
}

// MARK: - Invitation View Model
@MainActor
class InvitationViewModel: ObservableObject {
    @Published var invitations: [Invitation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService: DataService
    
    var stats: Invitation.InvitationStats {
        Invitation.getStats(for: invitations)
    }
    
    var pendingInvitations: [Invitation] {
        invitations.filter { $0.isPending }
    }
    
    var acceptedInvitations: [Invitation] {
        invitations.filter { $0.status == "accepted" }
    }
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func loadInvitations() {
        isLoading = true
        
        do {
            let predicate = #Predicate<Invitation> { _ in true }
            let sortDescriptor = [SortDescriptor<Invitation>(\.createdAt, order: .reverse)]
            invitations = try dataService.fetch(Invitation.self, filter: sortDescriptor, predicate: predicate)
            
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func resendInvitation(_ invitation: Invitation) {
        invitation.resend()
        try? dataService.save()
    }
    
    func cancelInvitation(_ invitation: Invitation) {
        invitation.cancel()
        try? dataService.save()
        loadInvitations()
    }
    
    func acceptInvitation(token: String) {
        guard let invitation = invitations.first(where: { $0.token == token }) else { return }
        
        if invitation.canAccept {
            invitation.accept()
            try? dataService.save()
        }
    }
    
    func declineInvitation(token: String) {
        guard let invitation = invitations.first(where: { $0.token == token }) else { return }
        
        if invitation.isPending {
            invitation.decline()
            try? dataService.save()
        }
    }
}

// MARK: - Preview
#Preview("Invitation View") {
    InvitationView(targetType: .workspace, targetId: "test-id", dataService: DataService())
}
