import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// "Today": what needs attention now, what comes next, and how projects are doing.
struct DashboardView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Query(filter: #Predicate<Workspace> { !$0.isArchived }) private var workspaces: [Workspace]
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.dueDate) private var projects: [Project]

    @State private var summary = DashboardSummary.empty
    @State private var focusTasks: [TaskItem] = []
    @State private var upcomingTasks: [TaskItem] = []

    var body: some View {
        PageScrollView {
                if workspaces.isEmpty {
                    emptyState
                } else {
                    header
                    statistics
                    taskSection(
                        title: "Focus",
                        subtitle: "Overdue and due today",
                        tasks: focusTasks,
                        emptyText: "Nothing due today. Enjoy the free time!"
                    )
                    taskSection(
                        title: "Upcoming",
                        subtitle: "Next 7 days",
                        tasks: upcomingTasks,
                        emptyText: "No tasks due in the next 7 days."
                    )
                    projectProgress
                }
        }
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    dependencies.router.present(.newTask(projectID: nil))
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .disabled(projects.isEmpty)
                .accessibilityIdentifier("dashboard.newTask")
            }
        }
        .task(id: dependencies.dataVersion) {
            reload()
        }
    }

    private func reload() {
        let dashboard = dependencies.dashboard
        summary = dependencies.errors.attempt { try dashboard.summary() } ?? .empty
        focusTasks = dependencies.errors.attempt { try dashboard.focusTasks() } ?? []
        upcomingTasks = dependencies.errors.attempt { try dashboard.upcomingTasks() } ?? []
    }

    private var header: some View {
        PageHeader(
            eyebrow: Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide)),
            title: Text(summary.dueToday == 0 && summary.overdue == 0
                        ? "You're all caught up."
                        : "\(summary.dueToday + summary.overdue) tasks need your attention.")
        )
    }

    private var statistics: some View {
        StatTileGrid {
            TFStatTile("Open", value: summary.openTasks, systemImage: "circle", tint: TFColor.accent)
            TFStatTile("Due today", value: summary.dueToday, systemImage: "sun.max", tint: .orange)
            TFStatTile("Overdue", value: summary.overdue, systemImage: "exclamationmark.circle", tint: TFColor.danger)
            TFStatTile("Done this week", value: summary.completedLast7Days, systemImage: "checkmark.circle", tint: TFColor.success)
        }
    }

    private func taskSection(title: LocalizedStringKey, subtitle: LocalizedStringKey, tasks: [TaskItem], emptyText: LocalizedStringKey) -> some View {
        CardSection(title: Text(title), subtitle: Text(subtitle)) {
                if tasks.isEmpty {
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, TFSpacing.small)
                } else {
                    ForEach(tasks) { task in
                        NavigationLink(value: Route.task(task.id)) {
                            TaskRow(task: task)
                        }
                        .buttonStyle(.plain)
                        if task.id != tasks.last?.id {
                            Divider()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var projectProgress: some View {
        let active = projects.filter { $0.status == .active && $0.workspace?.isArchived == false }
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: TFSpacing.small) {
                Text("Projects")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: TFSpacing.medium)], spacing: TFSpacing.medium) {
                    ForEach(active) { project in
                        NavigationLink(value: Route.project(project.id)) {
                            ProjectProgressCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Welcome to Projects", systemImage: "checklist")
        } description: {
            Text("Create a workspace for your first project.")
        } actions: {
            Button("Create Workspace") {
                dependencies.router.present(.newWorkspace)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("dashboard.createWorkspace")
        }
        .frame(minHeight: 400)
    }
}

/// A project with its completion progress.
struct ProjectProgressCard: View {
    let project: Project

    var body: some View {
        let stats = project.statistics(now: .now, calendar: .current)
        HStack(spacing: TFSpacing.medium) {
            IconTile(systemImage: project.symbolName, colorHex: project.colorHex)
            VStack(alignment: .leading, spacing: TFSpacing.xSmall) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(stats.completed) of \(stats.total) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TFProgressBar(progress: stats.completionRate, tint: Color(hex: project.colorHex))
            }
            if stats.overdue > 0 {
                TFBadge("\(stats.overdue)", systemImage: "exclamationmark.circle", tint: TFColor.danger)
                    .accessibilityLabel(Text("\(stats.overdue) overdue"))
            }
        }
        .tfCard(padding: TFSpacing.medium)
        .accessibilityElement(children: .combine)
    }
}
