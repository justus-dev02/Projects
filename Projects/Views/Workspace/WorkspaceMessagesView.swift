//
//  WorkspaceMessagesView.swift
//  Projects
//
//  TaskFlow - Workspace Messages/Chat View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Workspace Messages View Model
@MainActor
class WorkspaceMessagesViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var workspaceMembers: [WorkspaceMember] = []
    @Published var newMessageText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedWorkspace: Workspace?

    private let modelContext: ModelContext
    private let authService: AuthService

    init(
        modelContext: ModelContext,
        workspaceId: String? = nil,
        authService: AuthService? = nil
    ) {
        self.modelContext = modelContext
        self.authService = authService ?? AuthService(modelContext: modelContext)

        if let workspaceId = workspaceId {
            loadWorkspace(workspaceId: workspaceId)
        }
    }

    func loadWorkspace(workspaceId: String) {
        do {
            let descriptor = FetchDescriptor<Workspace>(
                predicate: #Predicate { $0.id == workspaceId }
            )
            selectedWorkspace = try modelContext.fetch(descriptor).first

            loadMessages()
            loadMembers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMessages() {
        do {
            let descriptor = FetchDescriptor<Message>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            messages = try modelContext.fetch(descriptor)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMembers() {
        do {
            let descriptor = FetchDescriptor<WorkspaceMember>(
                sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
            )
            workspaceMembers = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendMessage(_ text: String) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        guard let user = authService.currentUser else {
            throw NSError(domain: "Not authenticated", code: 401)
        }

        let message = Message(
            content: text.trimmingCharacters(in: .whitespacesAndNewlines),
            messageType: "text"
        )
        message.sender = user
        message.workspace = selectedWorkspace

        modelContext.insert(message)
        try modelContext.save()

        messages.append(message)
    }

    func deleteMessage(_ message: Message) throws {
        modelContext.delete(message)
        try modelContext.save()
        messages.removeAll { $0.id == message.id }
    }

    func addReaction(_ emoji: String, to message: Message) throws {
        guard let user = authService.currentUser else {
            throw NSError(domain: "Not authenticated", code: 401)
        }

        let reaction = MessageReaction(emoji: emoji)
        reaction.user = user
        reaction.message = message

        modelContext.insert(reaction)
        try modelContext.save()

        // Refresh messages to show reaction
        loadMessages()
    }

    var currentUser: User? {
        authService.currentUser
    }

    func getUserById(_ userId: String) -> User? {
        do {
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.id == userId }
            )
            return try modelContext.fetch(descriptor).first
        } catch {
            return nil
        }
    }
}

// MARK: - Workspace Messages View
struct WorkspaceMessagesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WorkspaceMessagesViewModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var isTextFieldFocused: Bool

    @State private var selectedMessage: Message?
    @State private var showingMemberList = false
    @State private var newMessageText = ""

    let workspaceId: String?

    init(workspaceId: String? = nil) {
        self.workspaceId = workspaceId
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                messagesContent(viewModel: vm)
            } else {
                ProgressView()
                    .onAppear {
                        viewModel = WorkspaceMessagesViewModel(modelContext: modelContext, workspaceId: workspaceId)
                    }
            }
        }
    }

    @ViewBuilder
    private func messagesContent(viewModel: WorkspaceMessagesViewModel) -> some View {
        VStack(spacing: 0) {
            // Header
            messageHeader(viewModel: viewModel)

            Divider()
                .foregroundColor(TaskFlowColors.border)

            // Messages List
            messagesList(viewModel: viewModel)

            Divider()
                .foregroundColor(TaskFlowColors.border)

            // Message Input
            messageInput(viewModel: viewModel)
        }
        .background(TaskFlowColors.background)
        .navigationTitle(viewModel.selectedWorkspace?.name ?? "Messages")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingMemberList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(TaskFlowColors.textPrimary)

                        Text("\(viewModel.workspaceMembers.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(TaskFlowColors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TaskFlowColors.border)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .sheet(isPresented: $showingMemberList) {
            WorkspaceMembersListView(members: viewModel.workspaceMembers)
        }
        .task {
            viewModel.loadMessages()
            viewModel.loadMembers()
        }
    }

    // MARK: - Header
    private func messageHeader(viewModel: WorkspaceMessagesViewModel) -> some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            if let workspace = viewModel.selectedWorkspace {
                ZStack {
                    Circle()
                        .fill(Color(hex: workspace.color).opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: workspace.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: workspace.color))
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(workspace.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    Text("\(viewModel.workspaceMembers.count) members")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Select a Workspace")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    Text("Choose a workspace to start chatting")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }

            Spacer()
        }
        .padding()
        .background(TaskFlowColors.surface)
    }

    // MARK: - Messages List
    private func messagesList(viewModel: WorkspaceMessagesViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: TaskFlowSpacing.medium, pinnedViews: []) {
                        ForEach(viewModel.messages, id: \.id) { message in
                            MessageBubble(
                                message: message,
                                isCurrentUser: message.sender?.id == viewModel.currentUser?.id,
                                onReact: { emoji in
                                    try? viewModel.addReaction(emoji, to: message)
                                },
                                onDelete: {
                                    try? viewModel.deleteMessage(message)
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                    .onChange(of: viewModel.messages.count) { newCount in
                        if newCount > 0, let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .onAppear {
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: TaskFlowSpacing.large) {
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)

            Text("No Messages Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            Text("Start the conversation with your team")
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Message Input
    private func messageInput(viewModel: WorkspaceMessagesViewModel) -> some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Attachment Button
            Button {
                // Show attachment picker
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18))
                    .foregroundColor(TaskFlowColors.textTertiary)
                    .padding(TaskFlowSpacing.small)
            }

            // Text Field
            TextField("Type a message...", text: $newMessageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, TaskFlowSpacing.medium)
                .padding(.vertical, TaskFlowSpacing.small)
                .background(TaskFlowColors.background)
                .cornerRadius(TaskFlowRadius.medium)
                .focused($isTextFieldFocused)
                .onSubmit {
                    try? viewModel.sendMessage(newMessageText)
                    newMessageText = ""
                }

            // Emoji Button
            Menu {
                ForEach(["👍", "❤️", "😂", "😮", "😢", "🎉"], id: \.self) { emoji in
                    Button {
                        newMessageText.append(emoji)
                    } label: {
                        Text(emoji)
                    }
                }
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 18))
                    .foregroundColor(TaskFlowColors.textTertiary)
                    .padding(TaskFlowSpacing.small)
            }

            // Send Button
            Button {
                try? viewModel.sendMessage(newMessageText)
                newMessageText = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(newMessageText.isEmpty ? TaskFlowColors.textTertiary : TaskFlowColors.primary)
                    .padding(TaskFlowSpacing.small)
            }
            .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, TaskFlowSpacing.large)
        .padding(.vertical, TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let onReact: (String) -> Void
    let onDelete: () -> Void

    @State private var showingReactionPicker = false
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: TaskFlowSpacing.xs) {
            // Sender Name
            if !isCurrentUser, let sender = message.sender {
                Text(sender.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: sender.avatarColor))
            }

            HStack(alignment: .bottom, spacing: TaskFlowSpacing.small) {
                if !isCurrentUser {
                    TFAvatar(
                        name: message.sender?.displayName ?? "?",
                        colorHex: message.sender?.avatarColor ?? "#95A5A6",
                        size: .small
                    )
                }

                VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 2) {
                    // Message Content
                    Text(message.content)
                        .font(.system(size: 14))
                        .foregroundColor(isCurrentUser ? .white : TaskFlowColors.textPrimary)
                        .padding(.horizontal, TaskFlowSpacing.medium)
                        .padding(.vertical, TaskFlowSpacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: TaskFlowRadius.large)
                                .fill(isCurrentUser ? TaskFlowColors.primary : TaskFlowColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TaskFlowRadius.large)
                                .stroke(
                                    isCurrentUser ? Color.clear : TaskFlowColors.border,
                                    lineWidth: 1
                                )
                        )

                    // Timestamp
                    Text(formatTimestamp(message.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)

                    // Reactions
                    if let reactions = message.reactions, !reactions.isEmpty {
                        ReactionBar(reactions: reactions, onReact: onReact)
                    }
                }

                if isCurrentUser {
                    TFAvatar(
                        name: message.sender?.displayName ?? "?",
                        colorHex: message.sender?.avatarColor ?? "#95A5A6",
                        size: .small
                    )
                }
            }
        }
        .contextMenu {
            Button {
                showingReactionPicker = true
            } label: {
                SwiftUI.Label("React", systemImage: "face.smiling")
            }

            Button {
                // Copy message
            } label: {
                SwiftUI.Label("Copy", systemImage: "doc.on.doc")
            }

            if isCurrentUser {
                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    SwiftUI.Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete Message", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this message?")
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "Yesterday 'at' h:mm a"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }
}

// MARK: - Reaction Bar
struct ReactionBar: View {
    let reactions: [MessageReaction]
    let onReact: (String) -> Void

    var groupedReactions: [String: [MessageReaction]] {
        Dictionary(grouping: reactions, by: { $0.emoji })
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(groupedReactions.keys.sorted(), id: \.self) { emoji in
                    Button {
                        onReact(emoji)
                    } label: {
                        HStack(spacing: 2) {
                            Text(emoji)
                                .font(.system(size: 12))

                            Text("\(groupedReactions[emoji]?.count ?? 0)")
                                .font(.system(size: 10))
                                .foregroundColor(TaskFlowColors.textSecondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TaskFlowColors.background)
                        .cornerRadius(TaskFlowRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: TaskFlowRadius.small)
                                .stroke(TaskFlowColors.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Workspace Members List View
struct WorkspaceMembersListView: View {
    @Environment(\.dismiss) private var dismiss
    let members: [WorkspaceMember]

    var body: some View {
        NavigationStack {
            List {
                ForEach(members, id: \.id) { member in
                    HStack(spacing: TaskFlowSpacing.medium) {
                        if let user = member.user {
                            TFAvatar(name: user.displayName, colorHex: user.avatarColor, size: .medium)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(TaskFlowColors.textPrimary)

                                Text(memberRoleText(member.role))
                                    .font(.system(size: 12))
                                    .foregroundColor(TaskFlowColors.textTertiary)
                            }
                        }

                        Spacer()

                        Text(formatJoinedDate(member.joinedAt))
                            .font(.system(size: 12))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                    .padding(.vertical, TaskFlowSpacing.small)
                }
            }
            .navigationTitle("Members")
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

    private func memberRoleText(_ role: String) -> String {
        switch role.lowercased() {
        case "owner": return "Owner"
        case "admin": return "Admin"
        case "member": return "Member"
        case "guest": return "Guest"
        default: return "Member"
        }
    }

    private func formatJoinedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview("Workspace Messages") {
    NavigationStack {
        WorkspaceMessagesView()
    }
}

