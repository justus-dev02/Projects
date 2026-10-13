import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Adds or edits a board column, including the status it represents.
struct ColumnEditorView: View {
    enum Target: Identifiable {
        case new(Project)
        case edit(BoardColumn)

        var id: UUID {
            switch self {
            case .new(let project): project.id
            case .edit(let column): column.id
            }
        }
    }

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let target: Target
    @State private var name = ""
    @State private var status = TaskStatus.todo
    @State private var colorHex = ColorPalette.gray
    @State private var hasLoaded = false

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(
                    title: nil,
                    footer: Text("Tasks moved into this column get this status. Tasks set to this status move into the first matching column.")
                ) {
                    CardRows {
                        TextField("Name", text: $name)
                            .font(.headline)
                            .cardTextField()
                            .cardRow()
                        CardPicker(title: "Status", selection: $status) {
                            ForEach(TaskStatus.allCases) { status in
                                Label(status.title, systemImage: status.symbolName).tag(status)
                            }
                        }
                    }
                }
                CardSection(title: Text("Color")) {
                    ColorPalettePicker(selection: $colorHex)
                        .cardRow()
                }
            }
            .sheetPage()
            .navigationTitle(isNew ? "New Column" : "Edit Column")
            .toolbar {
                EditorToolbar(
                    saveTitle: isNew ? "Add" : "Save",
                    canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                    onCancel: { dismiss() },
                    onSave: save
                )
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                if case .edit(let column) = target {
                    name = column.name
                    status = column.status
                    colorHex = column.colorHex
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func save() {
        let saved = dependencies.errors.perform {
            switch target {
            case .new(let project):
                try dependencies.projects.addColumn(to: project, name: name, status: status, colorHex: colorHex)
            case .edit(let column):
                try dependencies.projects.updateColumn(column, name: name, status: status, colorHex: colorHex)
            }
        }
        if saved { dismiss() }
    }
}
