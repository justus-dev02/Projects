import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// The project's tasks grouped by column, one card per column. Tasks can be reordered within a
/// column through the context menu.
struct ProjectTaskListView: View {
    @Environment(AppDependencies.self) private var dependencies
    let project: Project

    var body: some View {
        PageScrollView {
            ProjectPageHeader(project: project)
            if project.taskList.isEmpty {
                ContentUnavailableView {
                    Label("No Tasks Yet", systemImage: "checklist")
                } actions: {
                    Button("Add Task") { dependencies.router.present(.newTask(projectID: project.id)) }
                        .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                ForEach(project.sortedColumns) { column in
                    columnSection(column)
                }
            }
        }
    }

    private func columnSection(_ column: BoardColumn) -> some View {
        let tasks = column.sortedTasks
        return CardSection(title: Text(column.name), subtitle: Text("\(tasks.count) tasks")) {
            Circle()
                .fill(Color(hex: column.colorHex))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        } content: {
            if tasks.isEmpty {
                Text("No tasks in this column.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .cardRow()
            }
            LazyCardRows(data: tasks) { task in
                let index = tasks.firstIndex { $0.id == task.id } ?? 0
                NavigationLink(value: Route.task(task.id)) {
                    TaskRow(task: task, showsProject: false)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    ForEach([StepMove.Direction.upward, .downward], id: \.self) { direction in
                        let target = StepMove.targetIndex(from: index, direction: direction, count: tasks.count)
                        Button {
                            if let target { move(task, in: column, to: target) }
                        } label: {
                            direction == .upward
                                ? Label("Move Up", systemImage: "arrow.up")
                                : Label("Move Down", systemImage: "arrow.down")
                        }
                        .disabled(target == nil)
                    }
                    Divider()
                    TaskContextMenu(task: task)
                }
            }
        }
    }

    private func move(_ task: TaskItem, in column: BoardColumn, to index: Int) {
        withAnimation(.snappy) {
            _ = dependencies.errors.perform {
                try dependencies.tasks.move(task, to: column, at: index)
            }
        }
    }
}
