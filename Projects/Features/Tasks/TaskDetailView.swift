import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Resolves a task by identifier, so the view also works for deep links and shows a friendly
/// message if the task was deleted elsewhere.
struct TaskDetailView: View {
    @Query private var matches: [TaskItem]

    init(taskID: UUID) {
        _matches = Query(filter: #Predicate<TaskItem> { $0.id == taskID })
    }

    var body: some View {
        if let task = matches.first {
            TaskDetailContent(task: task)
        } else {
            NotFoundView(title: "Task Not Found")
        }
    }
}

private struct TaskDetailContent: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    let task: TaskItem

    @State private var confirmsDeletion = false
    @State private var asksTemplateName = false
    @State private var templateName = ""

    var body: some View {
        PageScrollView {
            header
            statusSection
            scheduleSection
            if !task.details.isEmpty {
                CardSection(title: Text("Notes")) {
                    Text(task.details)
                        .textSelection(.enabled)
                        .cardRow()
                }
            }
            TaskPeopleSection(task: task)
            QuestionsSection(task: task)
            TaskLabelsSection(task: task)
            SubtasksSection(task: task)
            DependenciesSection(task: task)
            if !(task.project?.customFields ?? []).isEmpty {
                CustomFieldsSection(task: task)
            }
            AttachmentsSection(task: task)
            CommentsSection(task: task)
            ActivitySection(task: task)
        }
        .navigationTitle(task.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbar }
        // Viewing the task marks comments that arrived from other devices as read, also when
        // new ones sync in while the task is open.
        .task(id: task.comments?.count ?? 0) {
            dependencies.errors.perform { try dependencies.tasks.markCommentsRead(of: task) }
        }
        .deleteConfirmation(
            "Delete Task?",
            message: "The task, its subtasks, comments and attachments will be deleted.",
            isPresented: $confirmsDeletion
        ) {
            dependencies.delete([task], undoManager: undoManager)
            dismiss()
        }
        .alert("Save as Template", isPresented: $asksTemplateName) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                let saved = dependencies.errors.perform {
                    try dependencies.templates.create(from: task, name: templateName)
                }
                if saved {
                    dependencies.toasts.show(String(localized: "Template saved"))
                }
            }
        } message: {
            Text("Templates include the title, notes, priority and subtasks.")
        }
    }

    /// Project as the small line, the task title as the sentence, like the header of "Today".
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: TFSpacing.medium) {
            CompletionButton(task: task)
            PageHeader(
                eyebrow: Text(task.project?.name ?? ""),
                title: Text(task.title).strikethrough(task.isCompleted)
            )
            .textSelection(.enabled)
        }
    }

    private var statusSection: some View {
        CardSection(title: nil) {
            if let project = task.project {
                CardNavigationRow(route: .project(project.id)) {
                    LabeledContent("Project") {
                        Label(project.name, systemImage: project.symbolName)
                            .labelStyle(.tfCompact)
                            .lineLimit(1)
                    }
                }
                CardDivider()
            }
            CardPicker(title: "Status", selection: Binding(
                get: { task.status },
                set: { status in dependencies.errors.perform { try dependencies.tasks.setStatus(task, to: status) } }
            )) {
                ForEach(TaskStatus.allCases) { status in
                    Label(status.title, systemImage: status.symbolName).tag(status)
                }
            }
            .accessibilityIdentifier("taskDetail.status")
            CardDivider()
            CardPicker(title: "Priority", selection: Binding(
                get: { task.priority },
                set: { priority in dependencies.errors.perform { try dependencies.tasks.setPriority([task], to: priority) } }
            )) {
                ForEach(TaskPriority.allCases.reversed()) { priority in
                    Label(priority.title, systemImage: priority.symbolName).tag(priority)
                }
            }
            if task.isBlocked, !task.isCompleted {
                CardDivider()
                Label {
                    Text("Waiting for \(task.openBlockers.map(\.title).formatted(.list(type: .and)))")
                } icon: {
                    Image(systemName: "lock.fill")
                }
                .foregroundStyle(TFColor.warning)
                .cardRow()
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        let hasSchedule = task.dueDate != nil || task.startDate != nil || task.reminderDate != nil
            || task.recurrence != nil || task.estimatedHours != nil || task.completedAt != nil
        if hasSchedule {
            CardSection(title: Text("Schedule")) {
                CardRows {
                    if let due = task.dueDate {
                        scheduleRow("Due") {
                            Text(due, format: .dateTime.weekday().day().month().hour().minute())
                                .foregroundStyle(task.isOverdue(now: .now) ? TFColor.danger : .secondary)
                        }
                    }
                    if let start = task.startDate {
                        scheduleRow("Starts") {
                            Text(start, format: .dateTime.weekday().day().month())
                        }
                    }
                    if let reminder = task.reminderDate {
                        scheduleRow("Reminder") {
                            Text(reminder, format: .dateTime.day().month().hour().minute())
                        }
                    }
                    if let recurrence = task.recurrence {
                        scheduleRow("Repeats") {
                            Text(recurrence.localizedDescription)
                        }
                    }
                    if let estimate = task.estimatedHours {
                        scheduleRow("Estimate") {
                            Text("\(estimate.formatted(.number.precision(.fractionLength(0...1)))) h")
                        }
                    }
                    if let completed = task.completedAt {
                        scheduleRow("Completed") {
                            Text(completed, format: .relative(presentation: .named))
                        }
                    }
                }
            }
        }
    }

    private func scheduleRow(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        LabeledContent(title, content: value)
            .cardRow()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Edit") {
                dependencies.router.present(.editTask(task.id))
            }
            .accessibilityIdentifier("taskDetail.edit")
        }
        ToolbarItem {
            Menu {
                Button {
                    dependencies.errors.perform { try dependencies.tasks.duplicate(task) }
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button {
                    templateName = task.title
                    asksTemplateName = true
                } label: {
                    Label("Save as Template", systemImage: "square.on.square")
                }
                ShareLink(item: task.deepLink.url, subject: Text(task.title)) {
                    Label("Share Link", systemImage: "link")
                }
                Divider()
                Button(role: .destructive) {
                    confirmsDeletion = true
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("taskDetail.more")
        }
    }
}
