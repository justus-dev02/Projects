import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Defines project specific fields such as "Story points" or "Customer".
struct CustomFieldsManagerView: View {
    @Query private var matches: [Project]

    init(projectID: UUID) {
        _matches = Query(filter: #Predicate<Project> { $0.id == projectID })
    }

    var body: some View {
        if let project = matches.first {
            CustomFieldsContent(project: project)
        } else {
            NotFoundView(title: "Project Not Found")
        }
    }
}

private struct CustomFieldsContent: View {
    @Environment(AppDependencies.self) private var dependencies
    let project: Project
    @State private var editedField: CustomFieldDefinition?
    @State private var isCreating = false

    var body: some View {
        let fields = project.sortedCustomFields
        PageScrollView {
            PageHeader(eyebrow: Text(project.name), title: Text("\(fields.count) custom fields"))
            if fields.isEmpty {
                ContentUnavailableView(
                    "No Custom Fields",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Add fields like “Story points” or “Customer” to every task in this project.")
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                CardSection(
                    title: Text("Fields"),
                    subtitle: Text("Shown on every task in this project"),
                    footer: Text("Touch and hold a field to reorder or delete it.")
                ) {
                    CardRows {
                        ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                            Button {
                                editedField = field
                            } label: {
                                HStack(spacing: TFSpacing.medium) {
                                    Image(systemName: field.type.symbolName)
                                        .foregroundStyle(TFColor.accent)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading) {
                                        Text(field.name)
                                        Text(field.type.title + (field.isRequired ? " · " + String(localized: "Required") : ""))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .cardRow()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                ForEach([StepMove.Direction.upward, .downward], id: \.self) { direction in
                                    Button {
                                        move(from: index, direction: direction, count: fields.count)
                                    } label: {
                                        direction == .upward
                                            ? Label("Move Up", systemImage: "arrow.up")
                                            : Label("Move Down", systemImage: "arrow.down")
                                    }
                                    .disabled(StepMove.targetIndex(from: index, direction: direction, count: fields.count) == nil)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    dependencies.errors.perform { try dependencies.projects.deleteCustomField(field) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Custom Fields")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreating = true
                } label: {
                    Label("New Field", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editedField) { field in
            CustomFieldEditor(project: project, field: field)
        }
        .sheet(isPresented: $isCreating) {
            CustomFieldEditor(project: project, field: nil)
        }
    }

    private func move(from index: Int, direction: StepMove.Direction, count: Int) {
        guard let destination = StepMove.onMoveDestination(from: index, direction: direction, count: count) else { return }
        dependencies.errors.perform {
            try dependencies.projects.moveCustomFields(in: project, fromOffsets: IndexSet(integer: index), toOffset: destination)
        }
    }
}

private struct CustomFieldEditor: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let field: CustomFieldDefinition?
    @State private var name = ""
    @State private var type = CustomFieldType.text
    @State private var optionsText = ""
    @State private var isRequired = false

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(
                    title: nil,
                    footer: field != nil ? Text("The type cannot be changed after the field was created.") : nil
                ) {
                    CardRows {
                        TextField("Name", text: $name)
                            .font(.headline)
                            .cardTextField()
                            .cardRow()
                        CardPicker(title: "Type", selection: $type) {
                            ForEach(CustomFieldType.allCases) { type in
                                Label(type.title, systemImage: type.symbolName).tag(type)
                            }
                        }
                        .disabled(field != nil)
                        Toggle("Required", isOn: $isRequired)
                            .cardRow()
                    }
                }
                if type.requiresOptions {
                    CardSection(title: Text("Options"), footer: Text("Values that refer to removed options are cleared.")) {
                        TextField("One option per line", text: $optionsText, axis: .vertical)
                            .lineLimit(3...10)
                            .cardTextField()
                            .cardRow()
                    }
                }
            }
            .sheetPage()
            .navigationTitle(field == nil ? "New Field" : "Edit Field")
            .toolbar {
                EditorToolbar(
                    saveTitle: field == nil ? "Add" : "Save",
                    canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .onAppear {
                if let field {
                    name = field.name
                    type = field.type
                    optionsText = field.options.joined(separator: "\n")
                    isRequired = field.isRequired
                }
            }
        }
    }

    private func save() {
        let options = optionsText.components(separatedBy: .newlines)
        let saved = dependencies.errors.perform {
            if let field {
                try dependencies.projects.updateCustomField(field, name: name, options: options, isRequired: isRequired)
            } else {
                try dependencies.projects.addCustomField(to: project, name: name, type: type, options: options, isRequired: isRequired)
            }
        }
        if saved { dismiss() }
    }
}
