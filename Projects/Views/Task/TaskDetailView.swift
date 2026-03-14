//
//  TaskDetailView.swift
//  Projects
//
//  TaskFlow - Task Detail View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Task Detail View Model
@MainActor
class TaskDetailViewModel: ObservableObject {
    let task: Task
    private let modelContext: ModelContext

    @Published var subtasks: [Subtask] = []
    @Published var comments: [Comment] = []
    @Published var labels: [TaskLabel] = []
    @Published var activityLogs: [ActivityLog] = []
    @Published var isLoading = false
    @Published var showingEditSheet = false
    @Published var newCommentText = ""
    @Published var newSubtaskText = ""

    private let taskRepo: TaskRepository
    private let dataService: DataService

    init(
        task: Task,
        modelContext: ModelContext,
        dataService: DataService? = nil,
        taskRepo: TaskRepository? = nil
    ) {
        self.task = task
        self.modelContext = modelContext
        self.dataService = dataService ?? DataService(modelContext: modelContext)
        self.taskRepo = taskRepo ?? TaskRepository(dataService: self.dataService)
        loadDetails()
    }
    
    func loadDetails() {
        isLoading = true
        
        subtasks = (task.subtasks ?? []).sorted { $0.order < $1.order }
        comments = (task.comments ?? []).sorted { $0.createdAt > $1.createdAt }
        labels = task.labels ?? []
        activityLogs = (task.activityLogs ?? []).sorted { $0.createdAt > $1.createdAt }
        
        isLoading = false
    }
    
    func toggleSubtask(_ subtask: Subtask) throws {
        try taskRepo.toggleSubtask(subtask)
        
        if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
            subtasks[index].isCompleted = subtask.isCompleted
        }
    }
    
    func addSubtask(title: String) throws {
        let subtask = try taskRepo.addSubtask(to: task, title: title)
        subtasks.append(subtask)
    }
    
    func deleteSubtask(_ subtask: Subtask) throws {
        try taskRepo.deleteSubtask(subtask)
        subtasks.removeAll { $0.id == subtask.id }
    }
    
    func addComment(content: String) throws {
        // In production, get current user from auth service
        guard let user = try? UserRepository(dataService: dataService).getCurrentUser() else {
            throw NSError(domain: "User not found", code: 404)
        }

        let comment = try taskRepo.addComment(to: task, content: content, author: user)
        comments.insert(comment, at: 0)
    }
    
    func deleteComment(_ comment: Comment) throws {
        try taskRepo.deleteComment(comment)
        comments.removeAll { $0.id == comment.id }
    }
    
    func addLabel(_ label: Label) throws {
        try taskRepo.addLabel(to: task, label: label)
        if let taskLabel = task.labels?.first(where: { $0.label?.id == label.id }) {
            labels.append(taskLabel)
        }
    }
    
    func removeLabel(_ taskLabel: TaskLabel) throws {
        try taskRepo.removeLabel(taskLabel, from: task)
        labels.removeAll { $0.id == taskLabel.id }
    }
    
    func updateTaskStatus(_ status: String) throws {
        try taskRepo.updateTask(task, status: status)
    }
    
    func deleteTask() throws {
        try taskRepo.deleteTask(task)
    }
    
    var completedSubtaskCount: Int {
        subtasks.filter { $0.isCompleted }.count
    }
    
    var totalSubtaskCount: Int {
        subtasks.count
    }
    
    var subtaskProgress: Double {
        guard totalSubtaskCount > 0 else { return 0 }
        return Double(completedSubtaskCount) / Double(totalSubtaskCount) * 100
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TaskDetailViewModel?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let task: Task

    var body: some View {
        Group {
            if let vm = viewModel {
                taskContent(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                viewModel = TaskDetailViewModel(
                    task: task,
                    modelContext: modelContext
                )
            }
        }
    }

    @ViewBuilder
    private func taskContent(viewModel: TaskDetailViewModel) -> some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad/Mac - Side by side
                HStack(spacing: 0) {
                    // Main Content
                    mainContent(viewModel: viewModel)

                    // Sidebar
                    sidebar(viewModel: viewModel)
                        .frame(width: 300)
                        .border(TaskFlowColors.border, width: 1)
                }
            } else {
                // iPhone - Stacked
                NavigationStack {
                    mainContent(viewModel: viewModel)
                }
            }
        }
        .background(TaskFlowColors.background)
    }
    
    // MARK: - Main Content
    private func mainContent(viewModel: TaskDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                // Header
                taskHeader(viewModel: viewModel)

                // Description
                if viewModel.task.taskDescription != nil {
                    descriptionSection(viewModel: viewModel)
                }

                // Subtasks
                subtasksSection(viewModel: viewModel)

                // Comments
                commentsSection(viewModel: viewModel)
            }
            .padding()
        }
    }

    // MARK: - Sidebar
    private func sidebar(viewModel: TaskDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                // Actions
                actionsSection(viewModel: viewModel)

                // Details
                detailsSection(viewModel: viewModel)

                // Labels
                labelsSection(viewModel: viewModel)

                // Activity
                activitySection(viewModel: viewModel)
            }
            .padding()
        }
    }

    // MARK: - Task Header
    private func taskHeader(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            // Status Badge
            TFStatusBadge(status: viewModel.task.status, size: .medium)

            // Title
            Text(viewModel.task.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(TaskFlowColors.textPrimary)

            // Meta Info
            HStack(spacing: TaskFlowSpacing.medium) {
                if let dueDate = viewModel.task.dueDate {
                    SwiftUI.Label(
                        formatDueDate(dueDate),
                        systemImage: "calendar"
                    )
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                }

                TFPriorityBadge(priority: viewModel.task.priority, size: .small)
            }

            // Assignee
            if let assignee = viewModel.task.assignee {
                HStack(spacing: TaskFlowSpacing.small) {
                    Text("Assigned to:")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)

                    TFUserAvatar(user: assignee, size: .small)

                    Text(assignee.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Description Section
    private func descriptionSection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Description")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            Text(viewModel.task.taskDescription!)
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Subtasks Section
    private func subtasksSection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            HStack {
                Text("Subtasks")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Spacer()

                Text("\(viewModel.completedSubtaskCount)/\(viewModel.totalSubtaskCount)")
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }

            // Progress
            TFTaskProgress(
                completed: viewModel.completedSubtaskCount,
                total: viewModel.totalSubtaskCount,
                height: 8
            )

            // Subtask List
            VStack(spacing: TaskFlowSpacing.small) {
                ForEach(viewModel.subtasks, id: \.id) { subtask in
                    SubtaskRow(
                        subtask: subtask,
                        onToggle: {
                            try? viewModel.toggleSubtask(subtask)
                        },
                        onDelete: {
                            try? viewModel.deleteSubtask(subtask)
                        }
                    )
                }
            }

            // Add Subtask
            AddSubtaskView { title in
                try? viewModel.addSubtask(title: title)
            }
        }
    }

    // MARK: - Comments Section
    private func commentsSection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Comments")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            // Comment List
            VStack(spacing: TaskFlowSpacing.medium) {
                ForEach(viewModel.comments, id: \.id) { comment in
                    CommentRow(comment: comment, onDelete: {
                        try? viewModel.deleteComment(comment)
                    })
                }
            }

            // Add Comment
            AddCommentView { content in
                try? viewModel.addComment(content: content)
            }
        }
    }

    // MARK: - Actions Section
    private func actionsSection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Actions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            VStack(spacing: TaskFlowSpacing.small) {
                TFButton(title: "Edit Task", style: .secondary, icon: "pencil") {
                    viewModel.showingEditSheet = true
                }

                if viewModel.task.status != "done" {
                    TFButton(title: "Mark Complete", style: .success, icon: "checkmark.circle.fill") {
                        try? viewModel.updateTaskStatus("done")
                        dismiss()
                    }
                }

                TFButton(title: "Delete Task", style: .danger, icon: "trash") {
                    try? viewModel.deleteTask()
                    dismiss()
                }
            }
        }
    }

    // MARK: - Details Section
    private func detailsSection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            DetailRow(
                icon: "calendar",
                label: "Created",
                value: formatDate(viewModel.task.createdAt)
            )

            DetailRow(
                icon: "clock",
                label: "Updated",
                value: formatDate(viewModel.task.updatedAt)
            )

            if let dueDate = viewModel.task.dueDate {
                DetailRow(
                    icon: "flag",
                    label: "Due Date",
                    value: formatDueDate(dueDate)
                )
            }

            if let estimatedHours = viewModel.task.estimatedHours {
                DetailRow(
                    icon: "hourglass",
                    label: "Estimated",
                    value: "\(estimatedHours)h"
                )
            }
        }
    }

    // MARK: - Labels Section
    private func labelsSection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Labels")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TaskFlowSpacing.small) {
                ForEach(viewModel.labels, id: \.id) { taskLabel in
                    if let label = taskLabel.label {
                        TFLabelBadge(name: label.name, colorHex: label.color, size: .medium)
                    }
                }
            }
        }
    }

    // MARK: - Activity Section
    private func activitySection(viewModel: TaskDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Text("Activity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)

            VStack(spacing: TaskFlowSpacing.small) {
                ForEach(viewModel.activityLogs.prefix(10), id: \.id) { log in
                    ActivityRow(activity: log)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Subtask Row
struct SubtaskRow: View {
    let subtask: Subtask
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Button(action: onToggle) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(subtask.isCompleted ? TaskFlowColors.success : TaskFlowColors.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(subtask.title)
                .font(.system(size: 14))
                .foregroundColor(subtask.isCompleted ? TaskFlowColors.textTertiary : TaskFlowColors.textPrimary)
                .strikethrough(subtask.isCompleted)
            
            Spacer()
            
            TFIconButton(icon: "trash", size: 14, style: .ghost) {
                onDelete()
            }
        }
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.small)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            HStack {
                if let author = comment.author {
                    TFUserAvatar(user: author, size: .small)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(author.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(TaskFlowColors.textPrimary)
                        
                        Text(formatDate(comment.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                }
                
                Spacer()
                
                TFIconButton(icon: "trash", size: 14, style: .ghost) {
                    onDelete()
                }
            }
            
            Text(comment.content)
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Comment View
struct AddCommentView: View {
    @State private var text = ""
    let onSubmit: (String) -> Void
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            TFTextField(
                placeholder: "Write a comment...",
                text: $text,
                multiline: false
            )
            
            TFButton(
                title: "Send",
                style: .primary,
                size: .small,
                icon: "paperplane.fill"
            ) {
                guard !text.isEmpty else { return }
                onSubmit(text)
                text = ""
            }
        }
    }
}

// MARK: - Add Subtask View
struct AddSubtaskView: View {
    @State private var text = ""
    let onSubmit: (String) -> Void
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            TFTextField(
                placeholder: "Add subtask...",
                text: $text,
                multiline: false
            )
            
            TFButton(
                title: "Add",
                style: .secondary,
                size: .small,
                icon: "plus"
            ) {
                guard !text.isEmpty else { return }
                onSubmit(text)
                text = ""
            }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(TaskFlowColors.textTertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(TaskFlowColors.textTertiary)
                
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textPrimary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let activity: ActivityLog

    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            Circle()
                .fill(TaskFlowColors.primary.opacity(0.2))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.logDescription)
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textPrimary)

                Text(formatDate(activity.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }

            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview("Task Detail") {
    let task = Task(title: "Design Homepage", taskDescription: "Create mockups for the new homepage design", priority: "high")
    return TaskDetailView(task: task)
}
