import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Creates, renames, recolors and deletes the labels of a workspace.
struct LabelManagerView: View {
    @Query private var matches: [Workspace]

    init(workspaceID: UUID) {
        _matches = Query(filter: #Predicate<Workspace> { $0.id == workspaceID })
    }

    var body: some View {
        if let workspace = matches.first {
            LabelManagerContent(workspace: workspace)
        } else {
            NotFoundView(title: "Workspace Not Found")
        }
    }
}

private struct LabelManagerContent: View {
    @Environment(AppDependencies.self) private var dependencies
    let workspace: Workspace
    @State private var editedLabel: TaskLabel?
    @State private var isCreating = false

    var body: some View {
        let labels = workspace.sortedLabels
        PageScrollView {
            PageHeader(eyebrow: Text(workspace.name), title: Text("\(labels.count) labels"))
            if labels.isEmpty {
                ContentUnavailableView("No Labels", systemImage: "tag", description: Text("Labels help you categorize tasks across projects."))
                    .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                CardSection(title: Text("Labels"), subtitle: Text("Tap a label to edit it")) {
                    CardRows {
                        ForEach(labels) { label in
                            Button {
                                editedLabel = label
                            } label: {
                                HStack {
                                    LabelChip(name: label.name, colorHex: label.colorHex)
                                    Spacer()
                                    Text("\(label.tasks?.count ?? 0) tasks")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .cardRow()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Edit") { editedLabel = label }
                                Button("Delete", role: .destructive) {
                                    dependencies.errors.perform { try dependencies.workspaces.deleteLabel(label) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Labels")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New Label", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editedLabel) { label in
            LabelEditor(label: label, workspace: workspace)
        }
        .sheet(isPresented: $isCreating) {
            LabelEditor(label: nil, workspace: workspace)
        }
    }
}

private struct LabelEditor: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let label: TaskLabel?
    let workspace: Workspace
    @State private var name = ""
    @State private var colorHex = ColorPalette.blue

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(title: nil) {
                    CardRows {
                        TextField("Name", text: $name)
                            .font(.headline)
                            .cardTextField()
                            .cardRow()
                        LabelChip(name: name.isEmpty ? String(localized: "Preview") : name, colorHex: colorHex)
                            .cardRow()
                    }
                }
                CardSection(title: Text("Color")) {
                    ColorPalettePicker(selection: $colorHex)
                        .cardRow()
                }
                if let label {
                    CardSection(title: nil, footer: Text("The label is removed from all tasks.")) {
                        Button("Delete Label", role: .destructive) {
                            if dependencies.errors.perform({ try dependencies.workspaces.deleteLabel(label) }) {
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderless)
                        .cardRow()
                    }
                }
            }
            .sheetPage()
            .navigationTitle(label == nil ? "New Label" : "Edit Label")
            .toolbar {
                EditorToolbar(
                    saveTitle: label == nil ? "Create" : "Save",
                    canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .onAppear {
                if let label {
                    name = label.name
                    colorHex = label.colorHex
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let saved = dependencies.errors.perform {
            if let label {
                try dependencies.workspaces.updateLabel(label, name: name, colorHex: colorHex)
            } else {
                try dependencies.workspaces.createLabel(in: workspace, name: name, colorHex: colorHex)
            }
        }
        if saved { dismiss() }
    }
}
