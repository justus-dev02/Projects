import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

extension EnvironmentValues {
    /// `true` when the list is wide enough to show task metadata in aligned columns.
    @Entry var wideTaskRows = false
}

/// Column widths of the wide task row, shared with ``TaskColumnsHeader`` so both line up.
nonisolated enum TaskColumn {
    static let project: CGFloat = 150
    static let people: CGFloat = 84
    static let due: CGFloat = 104
    static let priority: CGFloat = 96
    static let flags: CGFloat = 64
    static let dot: CGFloat = 12
    static let completionButton: CGFloat = 26
    /// Lists switch to the column layout from this width on.
    static let wideLayoutMinWidth: CGFloat = 720
}

/// One task in a list.
///
/// Narrow lists (iPhone, small windows) show the title with its metadata wrapped underneath.
/// Wide lists (iPad, Mac) show one line per task with aligned columns, like a table.
/// A dot on the trailing edge marks tasks with comments (green while one is unread).
struct TaskRow: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.wideTaskRows) private var isWide
    @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1
    let task: TaskItem
    var showsProject = true

    var body: some View {
        Group {
            if isWide {
                wideLayout
            } else {
                compactLayout
            }
        }
        .padding(.vertical, isWide ? TFSpacing.xxSmall : TFSpacing.xSmall)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: task.isCompleted ? Text("Mark as Open") : Text("Mark as Done")) {
            toggleCompletion()
        }
        .accessibilityIdentifier("task.row")
    }

    // MARK: Narrow

    private var compactLayout: some View {
        HStack(alignment: .center, spacing: TFSpacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: TFSpacing.medium) {
                CompletionButton(task: task)
                VStack(alignment: .leading, spacing: TFSpacing.xSmall + 2) {
                    title
                        .lineLimit(2)
                    compactMetadata
                }
            }
            Spacer(minLength: 0)
            CommentDot(task: task)
        }
    }

    @ViewBuilder
    private var compactMetadata: some View {
        let hasMetadata = showsProject || task.dueDate != nil || task.priority >= .high
            || task.subtaskCount > 0 || task.isBlocked || !(task.labels ?? []).isEmpty
            || !task.involvedPeople.isEmpty || task.openQuestionCount > 0
        if hasMetadata {
            FlowLayout(spacing: TFSpacing.small) {
                if showsProject, let project = task.project {
                    projectLabel(project)
                }
                if let dueDate = task.dueDate {
                    DueDateLabel(date: dueDate, isCompleted: task.isCompleted)
                }
                if task.priority >= .high {
                    PriorityBadge(task.priority)
                }
                subtaskProgress
                BlockedBadge(task: task)
                QuestionsBadge(openCount: task.openQuestionCount)
                PeopleBadge(names: task.involvedPeople, maxVisible: 3)
                ForEach(task.sortedLabels) { label in
                    LabelChip(name: label.name, colorHex: label.colorHex)
                }
            }
            // Lists render labels icon-only by default; the text is the information here.
            .labelStyle(.tfCompact)
        }
    }

    // MARK: Wide

    private var wideLayout: some View {
        HStack(alignment: .center, spacing: TFSpacing.medium) {
            CompletionButton(task: task)
            VStack(alignment: .leading, spacing: TFSpacing.xxSmall + 1) {
                title
                    .lineLimit(1)
                if task.subtaskCount > 0 || !(task.labels ?? []).isEmpty {
                    HStack(spacing: TFSpacing.small) {
                        subtaskProgress
                        ForEach(task.sortedLabels) { label in
                            LabelChip(name: label.name, colorHex: label.colorHex)
                        }
                    }
                    .labelStyle(.tfCompact)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsProject {
                Group {
                    if let project = task.project {
                        projectLabel(project)
                    }
                }
                .frame(width: TaskColumn.project * scale, alignment: .leading)
            }
            PeopleBadge(names: task.involvedPeople, maxVisible: 3)
                .frame(width: TaskColumn.people * scale, alignment: .leading)
            Group {
                if let dueDate = task.dueDate {
                    DueDateLabel(date: dueDate, isCompleted: task.isCompleted)
                }
            }
            .frame(width: TaskColumn.due * scale, alignment: .leading)
            PriorityBadge(task.priority)
                .frame(width: TaskColumn.priority * scale, alignment: .leading)
            HStack(spacing: TFSpacing.small) {
                BlockedBadge(task: task, showsText: false)
                QuestionsBadge(openCount: task.openQuestionCount)
            }
            .frame(width: TaskColumn.flags * scale, alignment: .leading)
            CommentDot(task: task)
                .frame(width: TaskColumn.dot, alignment: .center)
        }
    }

    // MARK: Parts

    private var title: some View {
        Text(task.title)
            .font(.body.weight(.medium))
            .strikethrough(task.isCompleted)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
    }

    private func projectLabel(_ project: Project) -> some View {
        Label {
            Text(project.name)
        } icon: {
            Image(systemName: project.symbolName)
                .foregroundStyle(Color(hex: project.colorHex))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.tfCompact)
        .lineLimit(1)
    }

    @ViewBuilder
    private var subtaskProgress: some View {
        if task.subtaskCount > 0 {
            Label("\(task.completedSubtaskCount)/\(task.subtaskCount)", systemImage: "checklist")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityLabel(Text("\(task.completedSubtaskCount) of \(task.subtaskCount) subtasks done"))
        }
    }

    private func toggleCompletion() {
        dependencies.errors.perform {
            try dependencies.tasks.toggleCompletion(task)
        }
    }
}

/// Column titles above wide task rows.
struct TaskColumnsHeader: View {
    @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1
    var showsProject = true

    var body: some View {
        HStack(spacing: TFSpacing.medium) {
            Text("Task")
                .frame(maxWidth: .infinity, alignment: .leading)
                // Aligns with the title, which starts after the completion button.
                .padding(.leading, TaskColumn.completionButton + TFSpacing.medium)
            if showsProject {
                Text("Project").frame(width: TaskColumn.project * scale, alignment: .leading)
            }
            Text("People").frame(width: TaskColumn.people * scale, alignment: .leading)
            Text("Due").frame(width: TaskColumn.due * scale, alignment: .leading)
            Text("Priority").frame(width: TaskColumn.priority * scale, alignment: .leading)
            Color.clear.frame(width: TaskColumn.flags * scale + TaskColumn.dot + TFSpacing.medium, height: 1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(nil)
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Switches the task rows inside to the column layout when the view is wide enough.
    func adaptiveTaskRows(_ isWide: Binding<Bool>) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width >= TaskColumn.wideLayoutMinWidth
        } action: { newValue in
            isWide.wrappedValue = newValue
        }
        .environment(\.wideTaskRows, isWide.wrappedValue)
    }
}

/// The round checkbox in front of a task.
struct CompletionButton: View {
    /// Optional: on the Mac, table cells of a just deleted row are laid out once more after they
    /// left the view hierarchy, where the environment is no longer available.
    @Environment(AppDependencies.self) private var dependencies: AppDependencies?
    let task: TaskItem

    var body: some View {
        Button {
            guard let dependencies else { return }
            dependencies.errors.perform {
                try dependencies.tasks.toggleCompletion(task)
            }
        } label: {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(color)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: TaskColumn.completionButton)
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.success, trigger: task.isCompleted) { _, isCompleted in isCompleted }
        // Tapping a blocked task still calls the service, which explains what it waits for.
        .help(isLocked ? Text("Blocked") : Text(verbatim: ""))
        .accessibilityLabel(task.isCompleted ? Text("Mark as Open") : Text("Mark as Done"))
        .accessibilityIdentifier("task.completion")
    }

    private var isLocked: Bool {
        task.isBlocked && !task.isCompleted
    }

    private var symbolName: String {
        if task.isCompleted { return "checkmark.circle.fill" }
        return isLocked ? "lock.circle" : "circle"
    }

    private var color: Color {
        if task.isCompleted { return TFColor.success }
        return isLocked ? TFColor.warning : task.priority.color
    }
}
