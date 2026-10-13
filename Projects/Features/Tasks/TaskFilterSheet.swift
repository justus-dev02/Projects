import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Edits a ``TaskFilter``. Changes apply immediately.
struct TaskFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: TaskFilter
    @Query(filter: #Predicate<Workspace> { !$0.isArchived }, sort: \Workspace.createdAt) private var workspaces: [Workspace]

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(title: nil) {
                    CardRows {
                        Toggle("Show completed tasks", isOn: $filter.includeCompleted)
                            .cardRow()
                        CardPicker(title: "Due", selection: $filter.due) {
                            ForEach(DueFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    }
                }
                CardSection(title: Text("Status")) {
                    CardRows {
                        ForEach(TaskStatus.allCases) { status in
                            Toggle(isOn: binding(for: status, in: \.statuses)) {
                                Label(status.title, systemImage: status.symbolName)
                                    .foregroundStyle(status.color)
                            }
                            .cardRow()
                        }
                    }
                }
                CardSection(title: Text("Priority")) {
                    CardRows {
                        ForEach(TaskPriority.allCases.reversed()) { priority in
                            Toggle(isOn: binding(for: priority, in: \.priorities)) {
                                Label(priority.title, systemImage: priority.symbolName)
                            }
                            .cardRow()
                        }
                    }
                }
                ForEach(workspaces) { workspace in
                    let labels = workspace.sortedLabels
                    if !labels.isEmpty {
                        CardSection(title: Text(workspace.name), subtitle: Text("Labels")) {
                            CardRows {
                                ForEach(labels) { label in
                                    Toggle(isOn: binding(for: label.id, in: \.labelIDs)) {
                                        LabelChip(name: label.name, colorHex: label.colorHex)
                                    }
                                    .cardRow()
                                }
                            }
                        }
                    }
                }
            }
            .sheetPage()
            .navigationTitle("Filter")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        filter = TaskFilter(searchText: filter.searchText)
                    }
                    .disabled(filter.isDefault)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding<Element: Hashable>(for element: Element, in keyPath: WritableKeyPath<TaskFilter, Set<Element>>) -> Binding<Bool> {
        Binding(
            get: { filter[keyPath: keyPath].contains(element) },
            set: { isOn in
                if isOn {
                    filter[keyPath: keyPath].insert(element)
                } else {
                    filter[keyPath: keyPath].remove(element)
                }
            }
        )
    }
}
