import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Creates or edits a project.
struct ProjectEditorView: View {
    enum Mode: Equatable {
        case create(workspaceID: UUID?)
        case edit(UUID)
    }

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workspace> { !$0.isArchived }, sort: \Workspace.createdAt) private var workspaces: [Workspace]

    let mode: Mode
    @State private var draft = ProjectDraft()
    @State private var workspaceID: UUID?
    @State private var hasStartDate = false
    @State private var hasDueDate = false
    @State private var hasLoaded = false

    private var project: Project? {
        guard case .edit(let id) = mode else { return nil }
        return try? dependencies.projects.project(id: id)
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty && workspaceID != nil
    }

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(title: nil) {
                    CardRows {
                        HStack(spacing: TFSpacing.medium) {
                            IconTile(systemImage: draft.symbolName, colorHex: draft.colorHex, size: 44)
                            TextField("Name", text: $draft.name)
                                .font(.headline)
                                .cardTextField()
                                .accessibilityIdentifier("projectEditor.name")
                        }
                        .cardRow()
                        TextField("Description", text: $draft.details, axis: .vertical)
                            .lineLimit(2...5)
                            .cardTextField()
                            .cardRow()
                        CardPicker(title: "Workspace", selection: $workspaceID) {
                            if workspaceID == nil {
                                Text("Choose a workspace").tag(UUID?.none)
                            }
                            ForEach(workspaces) { workspace in
                                Text(workspace.name).tag(Optional(workspace.id))
                            }
                        }
                        if project != nil {
                            CardPicker(title: "Status", selection: $draft.status) {
                                ForEach(ProjectStatus.allCases) { status in
                                    Label(status.title, systemImage: status.symbolName).tag(status)
                                }
                            }
                        }
                    }
                }
                CardSection(title: Text("Schedule")) {
                    CardRows {
                        Toggle("Start date", isOn: $hasStartDate.animation())
                            .cardRow()
                        if hasStartDate {
                            DatePicker("Starts", selection: dateBinding(\.startDate), displayedComponents: .date)
                                .cardRow()
                        }
                        Toggle("Due date", isOn: $hasDueDate.animation())
                            .cardRow()
                        if hasDueDate {
                            DatePicker("Due", selection: dateBinding(\.dueDate), displayedComponents: .date)
                                .cardRow()
                        }
                    }
                }
                CardSection(title: Text("Color")) {
                    ColorPalettePicker(selection: $draft.colorHex)
                        .cardRow()
                }
                CardSection(title: Text("Icon")) {
                    SymbolPicker(selection: $draft.symbolName, tint: Color(hex: draft.colorHex))
                        .cardRow()
                }
            }
            .sheetPage()
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                EditorToolbar(saveTitle: project == nil ? "Create" : "Save", canSave: canSave, onCancel: { dismiss() }, onSave: save)
            }
            .onAppear(perform: load)
        }
    }

    private func dateBinding(_ keyPath: WritableKeyPath<ProjectDraft, Date?>) -> Binding<Date> {
        Binding(get: { draft[keyPath: keyPath] ?? .now }, set: { draft[keyPath: keyPath] = $0 })
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        switch mode {
        case .create(let workspaceID):
            self.workspaceID = workspaceID ?? workspaces.first?.id
        case .edit:
            guard let project else { return }
            draft = ProjectDraft(project: project)
            workspaceID = project.workspace?.id
            hasStartDate = project.startDate != nil
            hasDueDate = project.dueDate != nil
        }
    }

    private func save() {
        var final = draft
        if !hasStartDate { final.startDate = nil } else if final.startDate == nil { final.startDate = .now }
        if !hasDueDate { final.dueDate = nil } else if final.dueDate == nil { final.dueDate = .now }
        guard let workspace = workspaces.first(where: { $0.id == workspaceID }) ?? project?.workspace else { return }

        let saved = dependencies.errors.perform {
            if let project {
                try dependencies.projects.update(project, with: final)
                if project.workspace?.id != workspace.id {
                    try dependencies.projects.move(project, to: workspace)
                }
            } else {
                let created = try dependencies.projects.create(final, in: workspace)
                dependencies.router.show(.projects)
                dependencies.router.projectsPath = [.workspace(workspace.id), .project(created.id)]
            }
        }
        if saved { dismiss() }
    }
}
