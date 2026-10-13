import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

/// Creates a new task or edits an existing one.
struct TaskEditorView: View {
    enum Mode: Equatable {
        case create(projectID: UUID?)
        case edit(UUID)
    }

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Project> { !$0.isArchived }, sort: \Project.name) private var projects: [Project]

    let mode: Mode

    @State private var draft = TaskDraft()
    @State private var projectID: UUID?
    @State private var hasLoaded = false
    @State private var hasStartDate = false
    @State private var hasDueDate = false
    @State private var hasReminder = false
    @State private var repeatFrequency: RecurrenceRule.Frequency?
    @State private var repeatInterval = 1
    @State private var estimateText = ""
    @FocusState private var isTitleFocused: Bool

    private var editedTask: TaskItem? {
        guard case .edit(let id) = mode else { return nil }
        return try? dependencies.tasks.task(id: id)
    }

    private var selectedProject: Project? {
        projects.first { $0.id == projectID } ?? editedTask?.project
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedProject != nil
    }

    var body: some View {
        NavigationStack {
            PageScrollView {
                CardSection(title: nil) {
                    CardRows {
                        TextField("Title", text: $draft.title, axis: .vertical)
                            .font(.headline)
                            .cardTextField()
                            .focused($isTitleFocused)
                            .cardRow()
                            .accessibilityIdentifier("taskEditor.title")
                        TextField("Notes", text: $draft.details, axis: .vertical)
                            .lineLimit(3...8)
                            .cardTextField()
                            .cardRow()
                            .accessibilityIdentifier("taskEditor.notes")
                    }
                }

                CardSection(title: nil) {
                    CardRows {
                        if case .create = mode {
                            CardPicker(title: "Project", selection: $projectID) {
                                Text("Choose a project").tag(UUID?.none)
                                ForEach(projects) { project in
                                    Text("\(project.workspace?.name ?? "") › \(project.name)").tag(Optional(project.id))
                                }
                            }
                            .accessibilityIdentifier("taskEditor.project")
                        }
                        CardPicker(title: "Priority", selection: $draft.priority) {
                            ForEach(TaskPriority.allCases.reversed()) { priority in
                                Label(priority.title, systemImage: priority.symbolName).tag(priority)
                            }
                        }
                    }
                }

                scheduleSection
                recurrenceSection
                labelsSection
                PeopleEditorSection(
                    names: draft.involvedPeople,
                    onAdd: addPerson,
                    onRemove: { name in draft.involvedPeople.removeAll { $0 == name } }
                )
            }
            .sheetPage()
            .navigationTitle(editedTask == nil ? "New Task" : "Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                EditorToolbar(saveTitle: editedTask == nil ? "Add" : "Save", canSave: canSave, onCancel: { dismiss() }, onSave: save)
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Sections

    private var scheduleSection: some View {
        CardSection(title: Text("Schedule")) {
            CardRows {
                Toggle("Due date", isOn: $hasDueDate.animation())
                    .cardRow()
                if hasDueDate {
                    DatePicker("Due", selection: dateBinding(\.dueDate, default: defaultDueDate))
                        .cardRow()
                }
                Toggle("Start date", isOn: $hasStartDate.animation())
                    .cardRow()
                if hasStartDate {
                    DatePicker("Starts", selection: dateBinding(\.startDate, default: .now), displayedComponents: .date)
                        .cardRow()
                }
                Toggle("Reminder", isOn: $hasReminder.animation())
                    .cardRow()
                if hasReminder {
                    DatePicker("Remind me", selection: dateBinding(\.reminderDate, default: defaultReminderDate))
                        .cardRow()
                }
                LabeledContent("Estimated hours") {
                    TextField("Estimated hours", text: $estimateText, prompt: Text("0"))
                        .multilineTextAlignment(.trailing)
                        .cardTextField()
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                .cardRow()
            }
        }
    }

    private var recurrenceSection: some View {
        CardSection(
            title: nil,
            footer: repeatFrequency != nil ? Text("When you complete the task, the next occurrence is created automatically.") : nil
        ) {
            CardRows {
                CardPicker(title: "Repeat", selection: $repeatFrequency.animation()) {
                    Text("Never").tag(RecurrenceRule.Frequency?.none)
                    ForEach(RecurrenceRule.Frequency.allCases) { frequency in
                        Text(frequency.title).tag(Optional(frequency))
                    }
                }
                if let frequency = repeatFrequency {
                    Stepper(value: $repeatInterval, in: 1...30) {
                        Text(RecurrenceRule(frequency: frequency, interval: repeatInterval).localizedDescription)
                    }
                    .cardRow()
                }
            }
        }
    }

    @ViewBuilder
    private var labelsSection: some View {
        let labels = selectedProject?.workspace?.sortedLabels ?? []
        if !labels.isEmpty {
            CardSection(title: Text("Labels")) {
                FlowLayout(spacing: TFSpacing.small) {
                    ForEach(labels) { label in
                        let isSelected = draft.labelIDs.contains(label.id)
                        Button {
                            if isSelected {
                                draft.labelIDs.remove(label.id)
                            } else {
                                draft.labelIDs.insert(label.id)
                            }
                        } label: {
                            LabelChip(name: label.name, colorHex: label.colorHex, isSelected: isSelected)
                                .overlay(alignment: .topTrailing) {
                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption2)
                                            .offset(x: 4, y: -4)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .cardRow()
            }
        }
    }

    // MARK: Logic

    /// Adds a name to the draft; the service validates again when the task is saved.
    private func addPerson(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= TaskService.maxPersonNameLength else {
            dependencies.errors.present(ProjectsError.fieldTooLong(.personName, maxLength: TaskService.maxPersonNameLength))
            return false
        }
        if !draft.involvedPeople.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            draft.involvedPeople.append(trimmed)
        }
        return true
    }

    private var defaultDueDate: Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private var defaultReminderDate: Date {
        (draft.dueDate ?? defaultDueDate).addingTimeInterval(-3600)
    }

    private func dateBinding(_ keyPath: WritableKeyPath<TaskDraft, Date?>, default fallback: Date) -> Binding<Date> {
        Binding(
            get: { draft[keyPath: keyPath] ?? fallback },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        switch mode {
        case .create(let projectID):
            self.projectID = projectID ?? projects.first?.id
            isTitleFocused = true
        case .edit:
            guard let task = editedTask else { return }
            draft = TaskDraft(task: task)
            projectID = task.project?.id
            hasStartDate = task.startDate != nil
            hasDueDate = task.dueDate != nil
            hasReminder = task.reminderDate != nil
            repeatFrequency = task.recurrence?.frequency
            repeatInterval = task.recurrence?.interval ?? 1
            estimateText = task.estimatedHours.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        }
    }

    /// The draft with the toggles applied (a switched-off date is removed).
    private func makeFinalDraft() -> TaskDraft {
        var final = draft
        if !hasStartDate { final.startDate = nil } else if final.startDate == nil { final.startDate = .now }
        if !hasDueDate { final.dueDate = nil } else if final.dueDate == nil { final.dueDate = defaultDueDate }
        if !hasReminder { final.reminderDate = nil } else if final.reminderDate == nil { final.reminderDate = defaultReminderDate }
        final.recurrence = repeatFrequency.map {
            RecurrenceRule(frequency: $0, interval: repeatInterval, endDate: editedTask?.recurrence?.endDate)
        }
        // Parse the estimate in the user's locale ("1,5" in German, "1.5" in English).
        let trimmedEstimate = estimateText.trimmingCharacters(in: .whitespaces)
        final.estimatedHours = trimmedEstimate.isEmpty ? nil : (try? Double(trimmedEstimate, format: .number))
        return final
    }

    private func save() {
        let final = makeFinalDraft()
        let succeeded = dependencies.errors.perform {
            if let task = editedTask {
                try dependencies.tasks.update(task, with: final)
            } else if let project = selectedProject {
                try dependencies.tasks.create(final, in: project)
            }
        }
        guard succeeded else { return }
        if final.reminderDate != nil {
            Task {
                // The reminder could not be scheduled without permission; schedule it now.
                if await dependencies.reminders.requestAuthorizationIfNeeded() {
                    await dependencies.refreshPlatformState()
                }
            }
        }
        dismiss()
    }
}
