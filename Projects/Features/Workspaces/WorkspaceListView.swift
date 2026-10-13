import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// All workspaces. Archived ones are collapsed in their own section.
struct WorkspaceListView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]
    @State private var workspacePendingDeletion: Workspace?
    @State private var showsArchived = false

    @State private var summary = DashboardSummary.empty

    var body: some View {
        let active = workspaces.filter { !$0.isArchived }
        let archived = workspaces.filter(\.isArchived)
        let projectCount = active.reduce(0) { $0 + $1.activeProjects.count }

        PageScrollView {
            if active.isEmpty && archived.isEmpty {
                ContentUnavailableView {
                    Label("No Workspaces", systemImage: "briefcase")
                } description: {
                    Text("Workspaces group related projects, for example “Work” and “Personal”.")
                } actions: {
                    Button("Create Workspace") { dependencies.router.present(.newWorkspace) }
                        .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                PageHeader(
                    eyebrow: Text("\(active.count) workspaces"),
                    title: Text("\(projectCount) active projects")
                )
                StatTileGrid {
                    TFStatTile("Workspaces", value: active.count, systemImage: "briefcase", tint: TFColor.accent)
                    TFStatTile("Active projects", value: projectCount, systemImage: "folder", tint: .blue)
                    TFStatTile("Open", value: summary.openTasks, systemImage: "circle", tint: .orange)
                    TFStatTile("Overdue", value: summary.overdue, systemImage: "exclamationmark.circle", tint: TFColor.danger)
                }
                ForEach(active) { workspace in
                    workspaceSection(workspace)
                }
                if !archived.isEmpty {
                    CardSection(title: Text("Archived"), subtitle: Text("\(archived.count) workspaces")) {
                        DisclosureGroup(isExpanded: $showsArchived) {
                            ForEach(archived) { workspace in
                                CardDivider()
                                workspaceLink(workspace)
                            }
                        } label: {
                            Text(showsArchived ? "Hide" : "Show")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dependencies.router.present(.newWorkspace)
                } label: {
                    Label("New Workspace", systemImage: "plus")
                }
                .accessibilityIdentifier("workspaces.new")
            }
        }
        .task(id: dependencies.dataVersion) {
            summary = dependencies.errors.attempt { try dependencies.dashboard.summary() } ?? .empty
        }
        .deleteConfirmation(
            "Delete Workspace?",
            message: "All projects, tasks, labels and templates in this workspace will be deleted. This cannot be undone.",
            isPresented: Binding(get: { workspacePendingDeletion != nil }, set: { if !$0 { workspacePendingDeletion = nil } })
        ) {
            if let workspace = workspacePendingDeletion {
                dependencies.errors.perform { try dependencies.workspaces.delete(workspace) }
            }
            workspacePendingDeletion = nil
        }
    }

    /// One workspace: a card that opens the workspace, followed by its projects with progress.
    private func workspaceSection(_ workspace: Workspace) -> some View {
        let projects = workspace.activeProjects
        return VStack(alignment: .leading, spacing: TFSpacing.medium) {
            workspaceLink(workspace)
                .tfCard(padding: TFSpacing.medium)
            if projects.isEmpty {
                Button {
                    dependencies.router.present(.newProject(workspaceID: workspace.id))
                } label: {
                    Label("New Project", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderless)
                .padding(.leading, TFSpacing.xSmall)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: TFSpacing.medium)], spacing: TFSpacing.medium) {
                    ForEach(projects) { project in
                        NavigationLink(value: Route.project(project.id)) {
                            ProjectProgressCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// The workspace's icon, name and project count. Opens the workspace; the context menu
    /// edits, archives or deletes it.
    private func workspaceLink(_ workspace: Workspace) -> some View {
        NavigationLink(value: Route.workspace(workspace.id)) {
            HStack(spacing: TFSpacing.medium) {
                IconTile(systemImage: workspace.symbolName, colorHex: workspace.colorHex)
                VStack(alignment: .leading, spacing: TFSpacing.xxSmall) {
                    Text(workspace.name)
                        .font(.headline)
                    Text("\(workspace.activeProjects.count) projects")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workspace.row")
        .contextMenu {
            Button("Edit") { dependencies.router.present(.editWorkspace(workspace.id)) }
            Button(workspace.isArchived ? "Restore" : "Archive") { toggleArchive(workspace) }
            Divider()
            Button("Delete", role: .destructive) { workspacePendingDeletion = workspace }
        }
    }

    private func toggleArchive(_ workspace: Workspace) {
        dependencies.errors.perform { try dependencies.workspaces.setArchived(workspace, !workspace.isArchived) }
    }
}
