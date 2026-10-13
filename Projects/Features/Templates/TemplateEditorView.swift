import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

struct TemplateEditorView: View {
    enum Mode: Equatable {
        case create(workspaceID: UUID?)
        case edit(UUID)
    }

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Workspace> { !$0.isArchived }, sort: \Workspace.createdAt) private var workspaces: [Workspace]
    @Query private var allTemplates: [TaskTemplate]

    let mode: Mode
    @State private var draft = TemplateDraft()
    @State private var workspaceID: UUID?
    @State private var subtasksText = ""
    @State private var hasLoaded = false

    private var template: TaskTemplate? {
        guard case .edit(let id) = mode else { return nil }
        return allTemplates.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(title: nil) {
                    CardRows {
                        TextField("Template name", text: $draft.name)
                            .font(.headline)
                            .cardTextField()
                            .cardRow()
                        CardPicker(title: "Category", selection: $draft.category) {
                            ForEach(TemplateCategory.allCases) { category in
                                Label(category.title, systemImage: category.symbolName).tag(category)
                            }
                        }
                        if template == nil {
                            CardPicker(title: "Workspace", selection: $workspaceID) {
                                ForEach(workspaces) { workspace in
                                    Text(workspace.name).tag(Optional(workspace.id))
                                }
                            }
                        }
                    }
                }
                CardSection(title: Text("Task")) {
                    CardRows {
                        TextField("Title", text: $draft.taskTitle)
                            .cardTextField()
                            .cardRow()
                        TextField("Notes", text: $draft.taskDetails, axis: .vertical)
                            .lineLimit(3...8)
                            .cardTextField()
                            .cardRow()
                        CardPicker(title: "Priority", selection: $draft.priority) {
                            ForEach(TaskPriority.allCases.reversed()) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                    }
                }
                CardSection(title: Text("Subtasks")) {
                    TextField("One subtask per line", text: $subtasksText, axis: .vertical)
                        .lineLimit(3...12)
                        .cardTextField()
                        .cardRow()
                }
            }
            .sheetPage()
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .toolbar {
                EditorToolbar(
                    saveTitle: template == nil ? "Create" : "Save",
                    canSave: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
                        && !draft.taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        && (template != nil || workspaceID != nil),
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        switch mode {
        case .create(let workspaceID):
            self.workspaceID = workspaceID ?? workspaces.first?.id
        case .edit:
            guard let template else { return }
            draft = TemplateDraft(template: template)
            subtasksText = template.subtaskTitles.joined(separator: "\n")
        }
    }

    private func save() {
        var final = draft
        final.subtaskTitles = subtasksText.components(separatedBy: .newlines)
        let saved = dependencies.errors.perform {
            if let template {
                try dependencies.templates.update(template, with: final)
            } else if let workspace = workspaces.first(where: { $0.id == workspaceID }) {
                try dependencies.templates.create(final, in: workspace)
            }
        }
        if saved { dismiss() }
    }
}
