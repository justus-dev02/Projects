import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Reusable task blueprints of all workspaces.
struct TemplatesView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Query(filter: #Predicate<Workspace> { !$0.isArchived }, sort: \Workspace.createdAt) private var workspaces: [Workspace]
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name) private var projects: [Project]

    var body: some View {
        let all = workspaces.flatMap(\.sortedTemplates)
        PageScrollView {
            if all.isEmpty {
                ContentUnavailableView {
                    Label("No Templates", systemImage: "square.on.square")
                } description: {
                    Text("Save recurring work like bug reports or meeting notes as templates. You can also save any task as a template.")
                } actions: {
                    Button("New Template") { dependencies.router.present(.newTemplate(workspaceID: nil)) }
                        .buttonStyle(.glassProminent)
                        .disabled(workspaces.isEmpty)
                }
                .frame(maxWidth: .infinity, minHeight: 400)
            } else {
                PageHeader(
                    eyebrow: Text("Reusable blueprints"),
                    title: Text("\(all.count) templates")
                )
                StatTileGrid {
                    TFStatTile("Templates", value: all.count, systemImage: "square.on.square", tint: TFColor.accent)
                    TFStatTile("Times used", value: all.reduce(0) { $0 + $1.usageCount }, systemImage: "arrow.counterclockwise", tint: TFColor.success)
                    TFStatTile("Categories", value: Set(all.map(\.category)).count, systemImage: "square.grid.2x2", tint: .orange)
                    TFStatTile("Subtasks", value: all.reduce(0) { $0 + $1.subtaskTitles.count }, systemImage: "checklist", tint: .blue)
                }
                ForEach(workspaces) { workspace in
                    let templates = workspace.sortedTemplates
                    if !templates.isEmpty {
                        CardSection(title: Text(workspace.name), subtitle: Text("\(templates.count) templates")) {
                            ForEach(templates) { template in
                                row(template, in: workspace)
                                if template.id != templates.last?.id {
                                    CardDivider()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dependencies.router.present(.newTemplate(workspaceID: nil))
                } label: {
                    Label("New Template", systemImage: "plus")
                }
                .disabled(workspaces.isEmpty)
            }
        }
    }

    private func row(_ template: TaskTemplate, in workspace: Workspace) -> some View {
        let targets = projects.filter { $0.workspace?.id == workspace.id }
        return HStack(spacing: TFSpacing.medium) {
            Image(systemName: template.category.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(TFColor.accent.opacity(0.1), in: .rect(cornerRadius: TFRadius.small))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TFSpacing.xxSmall) {
                Text(template.name).font(.headline)
                Text("\(template.category.title) · \(template.subtaskTitles.count) subtasks · used \(template.usageCount) times")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                ForEach(targets) { project in
                    Button(project.name) { instantiate(template, in: project) }
                }
            } label: {
                Label("Use", systemImage: "plus.circle")
            }
            .disabled(targets.isEmpty)
            .fixedSize()
        }
        .contentShape(.rect)
        .onTapGesture {
            dependencies.router.present(.editTemplate(template.id))
        }
        .padding(.vertical, TFSpacing.xSmall)
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Edit") { dependencies.router.present(.editTemplate(template.id)) }
            Button("Delete", role: .destructive) {
                dependencies.errors.perform { try dependencies.templates.delete(template) }
            }
        }
    }

    private func instantiate(_ template: TaskTemplate, in project: Project) {
        guard let task = dependencies.errors.attempt({ try dependencies.templates.instantiate(template, in: project) }) else { return }
        dependencies.router.templatesPath.append(.task(task.id))
    }
}
