import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Creates or edits a workspace.
struct WorkspaceEditorView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    let workspaceID: UUID?

    @State private var name = ""
    @State private var details = ""
    @State private var colorHex = ColorPalette.indigo
    @State private var symbolName = "briefcase"
    @State private var hasLoaded = false

    private var workspace: Workspace? {
        workspaceID.flatMap { try? dependencies.workspaces.workspace(id: $0) }
    }

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(title: nil) {
                    CardRows {
                        HStack(spacing: TFSpacing.medium) {
                            IconTile(systemImage: symbolName, colorHex: colorHex, size: 44)
                            TextField("Name", text: $name)
                                .font(.headline)
                                .cardTextField()
                                .accessibilityIdentifier("workspaceEditor.name")
                        }
                        .cardRow()
                        TextField("Description", text: $details, axis: .vertical)
                            .lineLimit(2...5)
                            .cardTextField()
                            .cardRow()
                    }
                }
                CardSection(title: Text("Color")) {
                    ColorPalettePicker(selection: $colorHex)
                        .cardRow()
                }
                CardSection(title: Text("Icon")) {
                    SymbolPicker(selection: $symbolName, tint: Color(hex: colorHex))
                        .cardRow()
                }
            }
            .sheetPage()
            .navigationTitle(workspaceID == nil ? "New Workspace" : "Edit Workspace")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                EditorToolbar(
                    saveTitle: workspaceID == nil ? "Create" : "Save",
                    canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
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
        guard let workspace else { return }
        name = workspace.name
        details = workspace.details
        colorHex = workspace.colorHex
        symbolName = workspace.symbolName
    }

    private func save() {
        let saved = dependencies.errors.perform {
            if let workspace {
                try dependencies.workspaces.update(workspace, name: name, details: details, colorHex: colorHex, symbolName: symbolName)
            } else {
                let created = try dependencies.workspaces.create(name: name, details: details, colorHex: colorHex, symbolName: symbolName)
                dependencies.router.show(.projects)
                dependencies.router.projectsPath = [.workspace(created.id)]
            }
        }
        if saved { dismiss() }
    }
}
