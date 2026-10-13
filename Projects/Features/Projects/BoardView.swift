import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// The Kanban board. Tasks can be moved with drag and drop, with the context menu
/// ("Move to") and with VoiceOver actions, so the board is fully usable without dragging.
struct BoardView: View {
    let project: Project
    let editColumn: (BoardColumn) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProjectPageHeader(project: project)
                .padding([.horizontal, .top])
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: TFSpacing.medium) {
                    ForEach(project.sortedColumns) { column in
                        BoardColumnView(column: column, project: project, editColumn: editColumn)
                    }
                }
                .padding()
            }
        }
        .background(TFColor.background)
        .accessibilityIdentifier("board")
    }
}

private struct BoardColumnView: View {
    @Environment(AppDependencies.self) private var dependencies
    let column: BoardColumn
    let project: Project
    let editColumn: (BoardColumn) -> Void
    @State private var isTargeted = false
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 290

    var body: some View {
        let tasks = column.sortedTasks
        VStack(alignment: .leading, spacing: TFSpacing.small) {
            header(count: tasks.count)
            ScrollView {
                LazyVStack(spacing: TFSpacing.small) {
                    ForEach(tasks) { task in
                        NavigationLink(value: Route.task(task.id)) {
                            BoardCard(task: task)
                        }
                        .buttonStyle(.plain)
                        .draggable(task.id.uuidString) {
                            BoardCard(task: task).frame(width: width - 24)
                        }
                        .dropDestination(for: String.self) { items, _ in
                            drop(items, at: tasks.firstIndex { $0.id == task.id } ?? tasks.count)
                        }
                        .contextMenu {
                            moveMenu(for: task)
                            TaskContextMenu(task: task)
                        }
                        .accessibilityActions {
                            ForEach(project.sortedColumns.filter { $0.id != column.id && task.canChangeStatus(to: $0.status) }) { target in
                                Button {
                                    move(task, to: target)
                                } label: {
                                    Text("Move to \(target.name)")
                                }
                            }
                        }
                    }
                    Button {
                        dependencies.router.present(.newTask(projectID: project.id))
                    } label: {
                        Label("Add Task", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(TFSpacing.small)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, TFSpacing.large)
            }
        }
        .padding(TFSpacing.small)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: TFRadius.large)
                .fill(laneColor)
        )
        .dropDestination(for: String.self) { items, _ in
            drop(items, at: column.sortedTasks.count)
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(column.name), \(tasks.count) tasks"))
    }

    /// A light tint of the column color. Gray columns get the accent tint instead, so the board
    /// never shows a gray lane.
    private var laneColor: Color {
        if !isTargeted, column.colorHex.caseInsensitiveCompare(ColorPalette.gray) == .orderedSame {
            return TFColor.rowBackground
        }
        return Color(hex: column.colorHex).opacity(isTargeted ? 0.18 : 0.07)
    }

    private func header(count: Int) -> some View {
        HStack(spacing: TFSpacing.small) {
            Circle()
                .fill(Color(hex: column.colorHex))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(column.name)
                .font(.headline)
            Text(count, format: .number)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            Menu {
                Button("Edit Column") { editColumn(column) }
                Button("Move Left") { moveColumn(by: -1) }
                    .disabled(column.order == 0)
                Button("Move Right") { moveColumn(by: 1) }
                    .disabled(column.order == project.sortedColumns.count - 1)
                Divider()
                Button("Delete Column", role: .destructive) {
                    dependencies.errors.perform { try dependencies.projects.deleteColumn(column) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Column Options"))
        }
        .padding(.horizontal, TFSpacing.xSmall)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func moveMenu(for task: TaskItem) -> some View {
        Menu {
            ForEach(project.sortedColumns.filter { $0.id != column.id }) { target in
                Button(target.name) { move(task, to: target) }
                    .disabled(!task.canChangeStatus(to: target.status))
            }
        } label: {
            Label("Move to", systemImage: "arrow.right.square")
        }
    }

    private func move(_ task: TaskItem, to target: BoardColumn) {
        withAnimation(.snappy) {
            _ = dependencies.errors.perform {
                try dependencies.tasks.move(task, to: target, at: target.sortedTasks.count)
            }
        }
    }

    private func moveColumn(by offset: Int) {
        dependencies.errors.perform {
            try dependencies.projects.moveColumn(column, to: column.order + offset)
        }
    }

    /// Accepts task identifiers dragged from this or another column.
    @discardableResult
    private func drop(_ items: [String], at index: Int) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)),
              let task = try? dependencies.tasks.task(id: id),
              task.project?.id == project.id else {
            return false
        }
        withAnimation(.snappy) {
            _ = dependencies.errors.perform {
                try dependencies.tasks.move(task, to: column, at: index)
            }
        }
        return true
    }
}

/// A task card on the board.
struct BoardCard: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: TFSpacing.small) {
            HStack(alignment: .top, spacing: TFSpacing.small) {
                VStack(alignment: .leading, spacing: TFSpacing.small) {
                    if !(task.labels ?? []).isEmpty {
                        FlowLayout(spacing: TFSpacing.xSmall) {
                            ForEach(task.sortedLabels) { label in
                                LabelChip(name: label.name, colorHex: label.colorHex)
                            }
                        }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        CompletionButton(task: task)
                        Text(task.title)
                            .font(.subheadline.weight(.medium))
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                CommentDot(task: task)
                    .padding(.top, TFSpacing.xSmall)
            }
            HStack(alignment: .bottom, spacing: TFSpacing.small) {
                FlowLayout(spacing: TFSpacing.small) {
                    if let due = task.dueDate {
                        DueDateLabel(date: due, isCompleted: task.isCompleted)
                    }
                    if task.priority >= .high {
                        PriorityBadge(task.priority)
                    }
                    if task.subtaskCount > 0 {
                        Label("\(task.completedSubtaskCount)/\(task.subtaskCount)", systemImage: "checklist")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    BlockedBadge(task: task)
                    QuestionsBadge(openCount: task.openQuestionCount)
                    if !(task.attachments ?? []).isEmpty {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Has attachments"))
                    }
                }
                .labelStyle(.tfCompact)
                Spacer(minLength: 0)
                PeopleBadge(names: task.involvedPeople, maxVisible: 3)
            }
        }
        .tfCard(padding: TFSpacing.medium)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("board.card")
    }
}
