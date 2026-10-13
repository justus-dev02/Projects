import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

// The cards of the task detail page. Each card is a ``CardSection`` like on "Today"; actions that
// lists offer as swipe gestures are available through context menus and visible buttons.

// MARK: - Labels

struct TaskLabelsSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem

    var body: some View {
        let labels = task.project?.workspace?.sortedLabels ?? []
        if !labels.isEmpty {
            CardSection(title: Text("Labels"), subtitle: Text("Tap to add or remove")) {
                FlowLayout(spacing: TFSpacing.small) {
                    ForEach(labels) { label in
                        let isOn = task.labelIDs.contains(label.id)
                        Button {
                            dependencies.errors.perform { try dependencies.tasks.toggleLabel(label, on: task) }
                        } label: {
                            LabelChip(name: label.name, colorHex: label.colorHex, isSelected: isOn)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .cardRow()
            }
        }
    }
}

// MARK: - Subtasks

struct SubtasksSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem
    @State private var newTitle = ""

    var body: some View {
        let subtasks = task.sortedSubtasks
        CardSection(
            title: Text("Subtasks"),
            subtitle: task.subtaskCount > 0 ? Text("\(task.completedSubtaskCount) of \(task.subtaskCount) done") : nil
        ) {
            if task.subtaskCount > 0 {
                TFProgressBar(progress: Double(task.completedSubtaskCount) / Double(task.subtaskCount), tint: TFColor.success)
                    .padding(.vertical, TFSpacing.small)
                    .accessibilityHidden(true)
            }
            ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
                HStack(spacing: TFSpacing.medium) {
                    Button {
                        dependencies.errors.perform { try dependencies.tasks.toggleSubtask(subtask) }
                    } label: {
                        Image(systemName: subtask.isCompleted ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(subtask.isCompleted ? TFColor.success : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(subtask.isCompleted ? Text("Mark as Open") : Text("Mark as Done"))
                    Text(subtask.title)
                        .strikethrough(subtask.isCompleted)
                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                }
                .cardRow()
                .accessibilityElement(children: .combine)
                .accessibilityValue(subtask.isCompleted ? Text("Done") : Text("Open"))
                .contextMenu {
                    stepButtons(index: index, count: subtasks.count)
                    Divider()
                    Button(role: .destructive) {
                        dependencies.errors.perform { try dependencies.tasks.deleteSubtask(subtask) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                CardDivider()
            }
            CardAddField(systemImage: "plus", prompt: "Add subtask", text: $newTitle, identifier: "subtasks.new", onSubmit: add)
        }
    }

    @ViewBuilder
    private func stepButtons(index: Int, count: Int) -> some View {
        Button {
            move(from: index, direction: .upward, count: count)
        } label: {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(StepMove.targetIndex(from: index, direction: .upward, count: count) == nil)
        Button {
            move(from: index, direction: .downward, count: count)
        } label: {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(StepMove.targetIndex(from: index, direction: .downward, count: count) == nil)
    }

    private func move(from index: Int, direction: StepMove.Direction, count: Int) {
        guard let destination = StepMove.onMoveDestination(from: index, direction: direction, count: count) else { return }
        dependencies.errors.perform {
            try dependencies.tasks.moveSubtasks(of: task, fromOffsets: IndexSet(integer: index), toOffset: destination)
        }
    }

    private func add() {
        let title = newTitle
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if dependencies.errors.perform({ try dependencies.tasks.addSubtask(to: task, title: title) }) {
            newTitle = ""
        }
    }
}

// MARK: - Dependencies

struct DependenciesSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem

    /// Tasks of the same project that can block this one without creating a cycle, by title.
    private var candidates: [TaskItem] {
        let projectTasks = (task.project?.taskList ?? [])
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        var graph: [UUID: Set<UUID>] = [:]
        for item in projectTasks {
            graph[item.id] = Set((item.blockedBy ?? []).map(\.id))
        }
        let allowed = Set(DependencyGraph.possibleBlockers(for: task.id, among: projectTasks.map(\.id), blockers: graph))
        return projectTasks.filter { allowed.contains($0.id) }
    }

    var body: some View {
        let candidates = candidates
        CardSection(
            title: Text("Blocked By"),
            footer: task.isBlocked && !task.isCompleted
                ? Text("This task stays in “To Do” until all blocking tasks are done.")
                : Text("A task with open blocking tasks cannot be started or completed.")
        ) {
            ForEach(task.blockers) { blocker in
                CardNavigationRow(route: .task(blocker.id)) {
                    HStack(spacing: TFSpacing.medium) {
                        Image(systemName: blocker.status.symbolName)
                            .foregroundStyle(blocker.status.color)
                            .accessibilityHidden(true)
                        Text(blocker.title)
                            .strikethrough(blocker.isCompleted)
                            .foregroundStyle(blocker.isCompleted ? .secondary : .primary)
                        Spacer(minLength: 0)
                        StatusBadge(blocker.status)
                    }
                }
                .contextMenu {
                    Button("Remove Dependency", role: .destructive) {
                        dependencies.errors.perform { try dependencies.tasks.removeDependency(task, blockedBy: blocker) }
                    }
                }
                CardDivider()
            }
            if !candidates.isEmpty {
                Menu {
                    ForEach(candidates) { candidate in
                        Button {
                            dependencies.errors.perform { try dependencies.tasks.addDependency(task, blockedBy: candidate) }
                        } label: {
                            Label(candidate.title, systemImage: candidate.status.symbolName)
                        }
                    }
                } label: {
                    Label("Add Blocking Task", systemImage: "link.badge.plus")
                        .cardRow()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("dependencies.add")
            } else if task.blockers.isEmpty {
                Text("There are no other tasks in this project yet.")
                    .foregroundStyle(.secondary)
                    .cardRow()
            }
            if !task.dependents.isEmpty {
                CardDivider()
                LabeledContent("Blocks") {
                    Text(task.dependents.map(\.title).formatted(.list(type: .and)))
                        .multilineTextAlignment(.trailing)
                }
                .cardRow()
            }
        }
    }
}

// MARK: - People

struct TaskPeopleSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem

    var body: some View {
        PeopleEditorSection(
            names: task.involvedPeople,
            onAdd: { name in
                dependencies.errors.perform { try dependencies.tasks.addPerson(named: name, to: task) }
            },
            onRemove: { name in
                dependencies.errors.perform { try dependencies.tasks.removePerson(named: name, from: task) }
            }
        )
    }
}

// MARK: - Questions

struct QuestionsSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem
    @State private var newQuestion = ""
    @State private var editedQuestion: TaskQuestion?
    @State private var editedText = ""

    var body: some View {
        CardSection(
            title: Text("Open Questions"),
            subtitle: task.openQuestionCount > 0 ? Text("\(task.openQuestionCount) open") : nil
        ) {
            ForEach(task.sortedQuestions) { question in
                HStack(alignment: .firstTextBaseline, spacing: TFSpacing.medium) {
                    Button {
                        dependencies.errors.perform { try dependencies.tasks.toggleQuestion(question) }
                    } label: {
                        Image(systemName: question.isAnswered ? "checkmark.bubble.fill" : "questionmark.bubble")
                            .font(.title3)
                            .foregroundStyle(question.isAnswered ? TFColor.success : TFColor.warning)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(question.isAnswered ? Text("Mark as Open") : Text("Mark as Answered"))
                    VStack(alignment: .leading, spacing: TFSpacing.xxSmall) {
                        Text(question.text)
                            .foregroundStyle(question.isAnswered ? .secondary : .primary)
                        if let answeredAt = question.answeredAt {
                            Text("Answered \(answeredAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .cardRow()
                .accessibilityElement(children: .combine)
                .accessibilityValue(question.isAnswered ? Text("Answered") : Text("Open"))
                .contextMenu {
                    Button("Edit") {
                        editedText = question.text
                        editedQuestion = question
                    }
                    Button("Delete", role: .destructive) { delete(question) }
                }
                CardDivider()
            }
            CardAddField(
                systemImage: "plus.bubble", prompt: "Add a question", text: $newQuestion,
                axis: .vertical, identifier: "questions.new", onSubmit: add
            )
        }
        .alert("Edit Question", isPresented: Binding(get: { editedQuestion != nil }, set: { if !$0 { editedQuestion = nil } })) {
            TextField("Question", text: $editedText)
            Button("Cancel", role: .cancel) { editedQuestion = nil }
            Button("Save") {
                if let question = editedQuestion {
                    let text = editedText
                    dependencies.errors.perform { try dependencies.tasks.editQuestion(question, text: text) }
                }
                editedQuestion = nil
            }
        }
    }

    private func add() {
        let text = newQuestion
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if dependencies.errors.perform({ try dependencies.tasks.addQuestion(to: task, text: text) }) {
            newQuestion = ""
        }
    }

    private func delete(_ question: TaskQuestion) {
        dependencies.errors.perform { try dependencies.tasks.deleteQuestion(question) }
    }
}

// MARK: - Custom fields

struct CustomFieldsSection: View {
    let task: TaskItem

    var body: some View {
        let definitions = task.project?.sortedCustomFields ?? []
        CardSection(title: Text("Fields")) {
            ForEach(definitions) { definition in
                CustomFieldValueEditor(task: task, definition: definition)
                    .cardRow()
                if definition.id != definitions.last?.id {
                    CardDivider()
                }
            }
        }
    }
}

private struct CustomFieldValueEditor: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem
    let definition: CustomFieldDefinition
    @State private var text = ""
    @State private var hasLoaded = false

    private var storedValue: String {
        task.customFieldValue(for: definition)?.value ?? ""
    }

    var body: some View {
        Group {
            switch definition.type {
            case .text, .url:
                LabeledContent(definition.name) {
                    TextField(definition.name, text: $text, prompt: Text(definition.isRequired ? "Required" : "Optional"))
                        .multilineTextAlignment(.trailing)
                        .cardTextField()
                        .onSubmit { commit(text) }
                        #if os(iOS)
                        .keyboardType(definition.type == .url ? .URL : .default)
                        .textInputAutocapitalization(definition.type == .url ? .never : .sentences)
                        #endif
                }
            case .number:
                LabeledContent(definition.name) {
                    TextField(definition.name, text: $text, prompt: Text("0"))
                        .multilineTextAlignment(.trailing)
                        .cardTextField()
                        .onSubmit { commitNumber() }
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            case .date:
                DatePicker(definition.name, selection: Binding(
                    get: { CustomFieldCodec.decodeDate(storedValue) ?? .now },
                    set: { commit(CustomFieldCodec.encode(date: $0)) }
                ), displayedComponents: .date)
            case .checkbox:
                Toggle(definition.name, isOn: Binding(
                    get: { CustomFieldCodec.decodeBool(storedValue) },
                    set: { commit(CustomFieldCodec.encode(bool: $0)) }
                ))
            case .choice:
                LabeledContent(definition.name) {
                    Picker(definition.name, selection: Binding(
                        get: { storedValue },
                        set: { commit($0) }
                    )) {
                        Text("None").tag("")
                        ForEach(definition.options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }
        .onAppear(perform: load)
        .onDisappear {
            if definition.type == .text || definition.type == .url, text != storedValue { commit(text) }
            if definition.type == .number { commitNumber() }
        }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        if definition.type == .number, let number = CustomFieldCodec.decodeNumber(storedValue) {
            text = number.formatted(.number.grouping(.never))
        } else {
            text = storedValue
        }
    }

    /// Converts locale formatted input ("1,5" in German) into the stored format.
    private func commitNumber() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            commit("")
            return
        }
        guard let number = try? Double(trimmed, format: .number) else {
            dependencies.errors.present(ProjectsError.invalidCustomFieldValue(fieldName: definition.name))
            return
        }
        let raw = CustomFieldCodec.encode(number: number)
        guard raw != storedValue else { return }
        commit(raw)
    }

    private func commit(_ raw: String) {
        guard raw != storedValue else { return }
        dependencies.errors.perform {
            try dependencies.tasks.setCustomFieldValue(raw, for: definition, on: task)
        }
    }
}

// MARK: - Comments

struct CommentsSection: View {
    @Environment(AppDependencies.self) private var dependencies
    let task: TaskItem
    @State private var newComment = ""
    @State private var editedComment: TaskComment?
    @State private var editedText = ""

    var body: some View {
        CardSection(
            title: Text("Comments"),
            subtitle: task.hasComments ? Text("\(task.comments?.count ?? 0) comments") : nil
        ) {
            ForEach(task.sortedComments) { comment in
                VStack(alignment: .leading, spacing: TFSpacing.xSmall) {
                    Text(comment.text)
                        .textSelection(.enabled)
                    if comment.authorDeviceID != dependencies.environment.installation.id, !comment.authorDeviceID.isEmpty {
                        Label("From another device", systemImage: "icloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.tfCompact)
                    }
                    HStack(spacing: TFSpacing.xSmall) {
                        Text(comment.createdAt, format: .relative(presentation: .named))
                        if comment.updatedAt > comment.createdAt.addingTimeInterval(1) {
                            Text("(edited)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .cardRow()
                .contextMenu {
                    Button("Edit") {
                        editedText = comment.text
                        editedComment = comment
                    }
                    Button("Delete", role: .destructive) { delete(comment) }
                }
                CardDivider()
            }
            HStack(alignment: .bottom, spacing: TFSpacing.medium) {
                TextField("Add a comment", text: $newComment, axis: .vertical)
                    .lineLimit(1...5)
                    .cardTextField()
                    .accessibilityIdentifier("comments.new")
                Button {
                    let text = newComment
                    if dependencies.errors.perform({ try dependencies.tasks.addComment(to: task, text: text) }) {
                        newComment = ""
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(Text("Send Comment"))
            }
            .cardRow()
        }
        .alert("Edit Comment", isPresented: Binding(get: { editedComment != nil }, set: { if !$0 { editedComment = nil } })) {
            TextField("Comment", text: $editedText)
            Button("Cancel", role: .cancel) { editedComment = nil }
            Button("Save") {
                if let comment = editedComment {
                    let text = editedText
                    dependencies.errors.perform { try dependencies.tasks.editComment(comment, text: text) }
                }
                editedComment = nil
            }
        }
    }

    private func delete(_ comment: TaskComment) {
        dependencies.errors.perform { try dependencies.tasks.deleteComment(comment) }
    }
}

// MARK: - Activity

struct ActivitySection: View {
    let task: TaskItem
    @State private var isExpanded = false

    var body: some View {
        let entries = task.sortedActivity
        CardSection(title: Text("Activity"), subtitle: Text("\(entries.count) entries")) {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(entries) { entry in
                    CardDivider()
                    HStack(alignment: .firstTextBaseline, spacing: TFSpacing.medium) {
                        Image(systemName: entry.kind.symbolName)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: TFSpacing.xxSmall) {
                            Text(entry.message)
                            Text(entry.createdAt, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .cardRow()
                    .accessibilityElement(children: .combine)
                }
            } label: {
                Text(isExpanded ? "Hide History" : "Show History")
                    .cardRow()
            }
        }
    }
}
