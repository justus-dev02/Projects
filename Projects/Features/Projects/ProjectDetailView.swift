import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// How a project's tasks are displayed.
enum ProjectViewMode: String, CaseIterable, Identifiable {
    case board
    case list
    case table
    case calendar
    case timeline

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .board: "Board"
        case .list: "List"
        case .table: "Table"
        case .calendar: "Calendar"
        case .timeline: "Timeline"
        }
    }

    var symbolName: String {
        switch self {
        case .board: "rectangle.split.3x1"
        case .list: "list.bullet"
        case .table: "tablecells"
        case .calendar: "calendar"
        case .timeline: "chart.bar.xaxis"
        }
    }
}

struct ProjectDetailView: View {
    @Query private var matches: [Project]

    init(projectID: UUID) {
        _matches = Query(filter: #Predicate<Project> { $0.id == projectID })
    }

    var body: some View {
        if let project = matches.first {
            ProjectDetailContent(project: project)
        } else {
            NotFoundView(title: "Project Not Found")
        }
    }
}

private struct ProjectDetailContent: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @AppStorage("project.viewMode") private var mode = ProjectViewMode.board
    let project: Project
    @State private var editedColumn: ColumnEditorView.Target?
    @State private var confirmsDeletion = false

    var body: some View {
        Group {
            switch mode {
            case .board:
                BoardView(project: project, editColumn: { editedColumn = .edit($0) })
            case .list:
                ProjectTaskListView(project: project)
            case .table:
                ProjectTableView(project: project)
            case .calendar:
                ProjectCalendarView(project: project)
            case .timeline:
                ProjectTimelineView(project: project)
            }
        }
        .navigationTitle(project.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $mode) {
                    ForEach(ProjectViewMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("project.viewMode")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dependencies.router.present(.newTask(projectID: project.id))
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .accessibilityIdentifier("project.newTask")
            }
            ToolbarItem {
                Menu {
                    Button {
                        dependencies.router.present(.editProject(project.id))
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }
                    Button {
                        editedColumn = .new(project)
                    } label: {
                        Label("Add Column", systemImage: "rectangle.badge.plus")
                    }
                    NavigationLink(value: Route.customFields(projectID: project.id)) {
                        Label("Custom Fields", systemImage: "list.bullet.rectangle")
                    }
                    Button {
                        dependencies.errors.perform { try dependencies.projects.setArchived(project, !project.isArchived) }
                    } label: {
                        Label(project.isArchived ? "Restore Project" : "Archive Project", systemImage: "archivebox")
                    }
                    ShareLink(item: project.deepLink.url, subject: Text(project.name)) {
                        Label("Share Link", systemImage: "link")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmsDeletion = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("project.more")
            }
        }
        .sheet(item: $editedColumn) { target in
            ColumnEditorView(target: target)
        }
        .deleteConfirmation(
            "Delete Project?",
            message: "All tasks in this project will be deleted. This cannot be undone.",
            isPresented: $confirmsDeletion
        ) {
            if dependencies.errors.perform({ try dependencies.projects.delete(project) }) {
                dismiss()
            }
        }
    }
}
