import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

struct WorkspaceDetailView: View {
    @Query private var matches: [Workspace]

    init(workspaceID: UUID) {
        _matches = Query(filter: #Predicate<Workspace> { $0.id == workspaceID })
    }

    var body: some View {
        if let workspace = matches.first {
            WorkspaceDetailContent(workspace: workspace)
        } else {
            NotFoundView(title: "Workspace Not Found")
        }
    }
}

private struct WorkspaceDetailContent: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let workspace: Workspace
    @State private var projectPendingDeletion: Project?
    @State private var confirmsWorkspaceDeletion = false

    var body: some View {
        let projects = workspace.projectList
        let active = projects.filter { !$0.isArchived }
        let archived = projects.filter(\.isArchived)

        let stats = active.map { $0.statistics(now: .now, calendar: .current) }

        PageScrollView {
            PageHeader(
                eyebrow: workspace.details.isEmpty ? Text("Workspace") : Text(workspace.details),
                title: Text("\(active.count) active projects")
            )
            StatTileGrid {
                TFStatTile("Projects", value: active.count, systemImage: "folder", tint: Color(hex: workspace.colorHex))
                TFStatTile("Open", value: stats.reduce(0) { $0 + $1.open }, systemImage: "circle", tint: TFColor.accent)
                TFStatTile("Overdue", value: stats.reduce(0) { $0 + $1.overdue }, systemImage: "exclamationmark.circle", tint: TFColor.danger)
                TFStatTile("Done this week", value: stats.reduce(0) { $0 + $1.completedLast7Days }, systemImage: "checkmark.circle", tint: TFColor.success)
            }
            CardSection(title: Text("Projects"), subtitle: Text("Progress of all active projects")) {
                CardRows {
                    if active.isEmpty {
                        Button {
                            dependencies.router.present(.newProject(workspaceID: workspace.id))
                        } label: {
                            Label("Create the first project", systemImage: "plus")
                                .cardRow()
                        }
                        .buttonStyle(.borderless)
                    }
                    ForEach(active) { project in
                        projectRow(project)
                    }
                }
            }
            if !archived.isEmpty {
                CardSection(title: Text("Archived"), subtitle: Text("\(archived.count) projects")) {
                    CardRows {
                        ForEach(archived) { project in
                            projectRow(project)
                        }
                    }
                }
            }
            CardSection(title: Text("Organize")) {
                CardNavigationRow(route: .labels(workspaceID: workspace.id)) {
                    LabeledContent {
                        Text(workspace.sortedLabels.count, format: .number)
                    } label: {
                        Label("Labels", systemImage: "tag")
                    }
                }
            }
        }
        .navigationTitle(workspace.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dependencies.router.present(.newProject(workspaceID: workspace.id))
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .accessibilityIdentifier("workspace.newProject")
            }
            ToolbarItem {
                Menu {
                    Button {
                        dependencies.router.present(.editWorkspace(workspace.id))
                    } label: {
                        Label("Edit Workspace", systemImage: "pencil")
                    }
                    Button {
                        dependencies.router.present(.newTemplate(workspaceID: workspace.id))
                    } label: {
                        Label("New Template", systemImage: "square.on.square")
                    }
                    Button {
                        dependencies.errors.perform { try dependencies.workspaces.setArchived(workspace, !workspace.isArchived) }
                    } label: {
                        Label(workspace.isArchived ? "Restore Workspace" : "Archive Workspace", systemImage: "archivebox")
                    }
                    Divider()
                    Button(role: .destructive) {
                        confirmsWorkspaceDeletion = true
                    } label: {
                        Label("Delete Workspace", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .deleteConfirmation(
            "Delete Project?",
            message: "All tasks in this project will be deleted. This cannot be undone.",
            isPresented: Binding(get: { projectPendingDeletion != nil }, set: { if !$0 { projectPendingDeletion = nil } })
        ) {
            if let project = projectPendingDeletion {
                dependencies.errors.perform { try dependencies.projects.delete(project) }
            }
            projectPendingDeletion = nil
        }
        .deleteConfirmation(
            "Delete Workspace?",
            message: "All projects, tasks, labels and templates in this workspace will be deleted. This cannot be undone.",
            isPresented: $confirmsWorkspaceDeletion
        ) {
            if dependencies.errors.perform({ try dependencies.workspaces.delete(workspace) }) {
                dismiss()
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        let stats = project.statistics(now: .now, calendar: .current)
        return NavigationLink(value: Route.project(project.id)) {
            HStack(spacing: TFSpacing.medium) {
                IconTile(systemImage: project.symbolName, colorHex: project.colorHex)
                VStack(alignment: .leading, spacing: TFSpacing.xSmall) {
                    HStack {
                        Text(project.name).font(.headline)
                        if project.status != .active {
                            TFBadge(project.status.title, systemImage: project.status.symbolName, tint: project.status.color)
                        }
                    }
                    TFProgressBar(progress: stats.completionRate, tint: Color(hex: project.colorHex))
                    Text("\(stats.completed) of \(stats.total) done")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .cardRow()
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("project.row")
        .contextMenu {
            Button("Edit") { dependencies.router.present(.editProject(project.id)) }
            Button(project.isArchived ? "Restore" : "Archive") {
                dependencies.errors.perform { try dependencies.projects.setArchived(project, !project.isArchived) }
            }
            Divider()
            Button("Delete", role: .destructive) { projectPendingDeletion = project }
        }
    }
}
