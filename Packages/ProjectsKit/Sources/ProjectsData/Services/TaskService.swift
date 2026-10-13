import Foundation
import SwiftData
import ProjectsCore

/// The editable properties of a task, used by the task editor and by App Intents.
public struct TaskDraft: Equatable, Sendable {
    public var title: String
    public var details: String
    public var priority: TaskPriority
    public var startDate: Date?
    public var dueDate: Date?
    public var reminderDate: Date?
    public var estimatedHours: Double?
    public var recurrence: RecurrenceRule?
    public var labelIDs: Set<UUID>
    public var involvedPeople: [String]

    public init(
        title: String = "",
        details: String = "",
        priority: TaskPriority = .medium,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        reminderDate: Date? = nil,
        estimatedHours: Double? = nil,
        recurrence: RecurrenceRule? = nil,
        labelIDs: Set<UUID> = [],
        involvedPeople: [String] = []
    ) {
        self.title = title
        self.details = details
        self.priority = priority
        self.startDate = startDate
        self.dueDate = dueDate
        self.reminderDate = reminderDate
        self.estimatedHours = estimatedHours
        self.recurrence = recurrence
        self.labelIDs = labelIDs
        self.involvedPeople = involvedPeople
    }

    public init(task: TaskItem) {
        self.init(
            title: task.title,
            details: task.details,
            priority: task.priority,
            startDate: task.startDate,
            dueDate: task.dueDate,
            reminderDate: task.reminderDate,
            estimatedHours: task.estimatedHours,
            recurrence: task.recurrence,
            labelIDs: task.labelIDs,
            involvedPeople: task.involvedPeople
        )
    }
}

/// Applies the side effects of a status change that every code path must share.
enum TaskStatusTransition {
    static func apply(_ status: TaskStatus, to task: TaskItem, now: Date) {
        let wasCompleted = task.isCompleted
        task.status = status
        if status.isCompleted, !wasCompleted {
            task.completedAt = now
        } else if !status.isCompleted {
            task.completedAt = nil
        }
        task.updatedAt = now
    }
}

/// All write operations on tasks and their children.
///
/// Every public method validates its input, keeps board position and status consistent,
/// records activity, saves, and informs the ``TaskChangeObserving`` observer.
public final class TaskService {
    let environment: ServiceEnvironment

    public init(environment: ServiceEnvironment) {
        self.environment = environment
    }

    var context: ModelContext { environment.context }

    // MARK: Queries

    public func task(id: UUID) throws -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try environment.fetch(descriptor).first
    }

    // MARK: Create & update

    /// Creates a task at the end of `column`, or of the project's first "To Do" column.
    @discardableResult
    public func create(_ draft: TaskDraft, in project: Project, column: BoardColumn? = nil) throws -> TaskItem {
        let title = try Validation.name(draft.title, field: .taskTitle, maxLength: 200)
        let details = try Validation.details(draft.details, field: .taskTitle)
        let people = try Self.normalizedPeople(draft.involvedPeople)
        let now = environment.now()
        let target = column ?? project.firstColumn(for: .todo) ?? project.sortedColumns.first

        let task = TaskItem(title: title, details: details, status: target?.status ?? .todo, priority: draft.priority)
        task.createdAt = now
        task.updatedAt = now
        context.insert(task)
        task.project = project
        task.column = target
        task.order = SparseOrder.appendKey(after: (target?.tasks ?? []).filter { $0.id != task.id }.map(\.order))
        if task.isCompleted {
            task.completedAt = now
        }
        applyScheduling(of: draft, to: task)
        task.labels = labels(withIDs: draft.labelIDs, in: project)
        task.involvedPeople = people
        addActivity(.created, to: task)

        try environment.save(changed: [task])
        Log.services.info("Task created")
        return task
    }

    public func update(_ task: TaskItem, with draft: TaskDraft) throws {
        let title = try Validation.name(draft.title, field: .taskTitle, maxLength: 200)
        let details = try Validation.details(draft.details, field: .taskTitle)
        let people = try Self.normalizedPeople(draft.involvedPeople)

        if draft.priority != task.priority {
            addActivity(.priorityChanged, detail: String(draft.priority.rawValue), to: task)
        }
        if draft.dueDate != task.dueDate {
            addActivity(.dueDateChanged, detail: draft.dueDate.map(CustomFieldCodec.encode(date:)), to: task)
        }

        task.title = title
        task.details = details
        task.priority = draft.priority
        task.involvedPeople = people
        applyScheduling(of: draft, to: task)
        if let project = task.project {
            task.labels = labels(withIDs: draft.labelIDs, in: project)
        }
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    /// Changes the status and moves the task into the first column representing that status.
    /// Completing a recurring task creates its next occurrence.
    /// - Returns: The next occurrence, if one was created.
    /// - Throws: ``ProjectsError/taskBlocked(taskTitle:blockerTitles:)`` when the task should
    ///   leave "To Do" while a blocking task is not done.
    @discardableResult
    public func setStatus(_ task: TaskItem, to status: TaskStatus) throws -> TaskItem? {
        guard task.status != status else { return nil }
        try ensureCanChangeStatus(of: task, to: status)
        if let column = task.column, column.status != status,
           let target = task.project?.firstColumn(for: status) {
            placeAtEnd(task, of: target)
        }
        let spawned = applyStatusChange(status, to: task)
        try environment.save(changed: [task] + (spawned.map { [$0] } ?? []))
        return spawned
    }

    /// Toggles between done and the status of the board's first column.
    @discardableResult
    public func toggleCompletion(_ task: TaskItem) throws -> TaskItem? {
        try setStatus(task, to: task.isCompleted ? .todo : .done)
    }

    /// Moves a task to `index` in `column` (also across columns) and adopts the column's status.
    ///
    /// Only the moved task gets a new sort key (see ``SparseOrder``), unless its new neighbours
    /// have no free key between them; then the column is renumbered once.
    /// - Returns: The next occurrence when the move completed a recurring task.
    /// - Throws: ``ProjectsError/taskBlocked(taskTitle:blockerTitles:)`` when the target column
    ///   would start a blocked task.
    @discardableResult
    public func move(_ task: TaskItem, to column: BoardColumn, at index: Int) throws -> TaskItem? {
        try ensureCanChangeStatus(of: task, to: column.status)
        let source = task.column
        let now = environment.now()

        let others = column.sortedTasks.filter { $0.id != task.id }
        if source?.id != column.id {
            task.column = column
            addActivity(.moved, detail: column.name, to: task)
        }
        position(task, at: index, among: others)

        var spawned: TaskItem?
        if task.status != column.status {
            spawned = applyStatusChange(column.status, to: task)
        }
        task.updatedAt = now
        try environment.save(changed: [task] + (spawned.map { [$0] } ?? []))
        return spawned
    }

    @discardableResult
    public func duplicate(_ task: TaskItem) throws -> TaskItem {
        guard let project = task.project else { throw ProjectsError.notFound(.project) }
        var draft = TaskDraft(task: task)
        draft.title = String(localized: "\(task.title) (Copy)", bundle: .module, comment: "Title of a duplicated task")
        if draft.title.count > 200 {
            draft.title = String(draft.title.prefix(200))
        }
        let copy = try create(draft, in: project, column: task.column)
        for (index, subtask) in task.sortedSubtasks.enumerated() {
            let newSubtask = Subtask(title: subtask.title, order: index * SparseOrder.spacing)
            newSubtask.createdAt = environment.now()
            context.insert(newSubtask)
            newSubtask.task = copy
        }
        for value in task.customFieldValues ?? [] {
            let newValue = CustomFieldValue(value: value.value)
            context.insert(newValue)
            newValue.definition = value.definition
            newValue.task = copy
        }
        try environment.save(changed: [copy])
        return copy
    }

    public func delete(_ task: TaskItem) throws {
        try delete([task])
    }

    public func delete(_ tasks: [TaskItem]) throws {
        let ids = tasks.map(\.id)
        for task in tasks {
            context.delete(task)
        }
        try environment.save(deleted: ids)
    }

    /// Moves the reminder by `interval` from now, e.g. for the "Snooze" notification action.
    public func snoozeReminder(of task: TaskItem, by interval: TimeInterval) throws {
        task.reminderDate = environment.now().addingTimeInterval(interval)
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    // MARK: Bulk operations

    /// Applies a status to several tasks. Returns the number of tasks that changed.
    /// Nothing changes if one of the tasks is blocked from that status.
    @discardableResult
    public func setStatus(_ tasks: [TaskItem], to status: TaskStatus) throws -> Int {
        for task in tasks {
            try ensureCanChangeStatus(of: task, to: status)
        }
        var changed: [TaskItem] = []
        for task in tasks where task.status != status {
            if let target = task.project?.firstColumn(for: status), task.column?.status != status {
                placeAtEnd(task, of: target)
            }
            if let spawned = applyStatusChange(status, to: task) {
                changed.append(spawned)
            }
            changed.append(task)
        }
        try environment.save(changed: changed)
        return changed.count
    }

    public func setPriority(_ tasks: [TaskItem], to priority: TaskPriority) throws {
        let now = environment.now()
        for task in tasks where task.priority != priority {
            task.priority = priority
            task.updatedAt = now
            addActivity(.priorityChanged, detail: String(priority.rawValue), to: task)
        }
        try environment.save(changed: tasks)
    }

    public func setDueDate(_ tasks: [TaskItem], to dueDate: Date?) throws {
        let now = environment.now()
        for task in tasks where task.dueDate != dueDate {
            task.dueDate = dueDate
            task.updatedAt = now
            addActivity(.dueDateChanged, detail: dueDate.map(CustomFieldCodec.encode(date:)), to: task)
        }
        try environment.save(changed: tasks)
    }

    // MARK: Subtasks

    @discardableResult
    public func addSubtask(to task: TaskItem, title: String) throws -> Subtask {
        let order = SparseOrder.appendKey(after: (task.subtasks ?? []).map(\.order))
        let subtask = Subtask(title: try Validation.name(title, field: .subtaskTitle, maxLength: 200), order: order)
        subtask.createdAt = environment.now()
        context.insert(subtask)
        subtask.task = task
        addActivity(.subtaskAdded, to: task)
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
        return subtask
    }

    public func toggleSubtask(_ subtask: Subtask) throws {
        subtask.isCompleted.toggle()
        subtask.completedAt = subtask.isCompleted ? environment.now() : nil
        subtask.task?.updatedAt = environment.now()
        try environment.save(changed: subtask.task.map { [$0] } ?? [])
    }

    public func renameSubtask(_ subtask: Subtask, to title: String) throws {
        subtask.title = try Validation.name(title, field: .subtaskTitle, maxLength: 200)
        try environment.save(changed: subtask.task.map { [$0] } ?? [])
    }

    public func deleteSubtask(_ subtask: Subtask) throws {
        let task = subtask.task
        context.delete(subtask)
        try environment.save(changed: task.map { [$0] } ?? [])
    }

    /// Reorders subtasks with `List.onMove` semantics. Moving a single subtask only changes its key.
    public func moveSubtasks(of task: TaskItem, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        let subtasks = task.sortedSubtasks
        let ids = OrderedMove.move(subtasks.map(\.id), fromOffsets: source, toOffset: destination)
        if source.count == 1, let offset = source.first, subtasks.indices.contains(offset),
           let newIndex = ids.firstIndex(of: subtasks[offset].id) {
            let moved = subtasks[offset]
            let others = subtasks.filter { $0.id != moved.id }
            if let key = SparseOrder.key(insertingAt: newIndex, between: others.map(\.order)) {
                moved.order = key
                try environment.save(changed: [task])
                return
            }
        }
        let byID = Dictionary(uniqueKeysWithValues: subtasks.map { ($0.id, $0) })
        for (id, key) in zip(ids, SparseOrder.renumbered(count: ids.count)) {
            byID[id]?.order = key
        }
        try environment.save(changed: [task])
    }

    // MARK: Attachments

    /// Stores a copy of the file inside the database, so attachments survive restarts,
    /// sandboxing and syncing to other devices.
    @discardableResult
    public func addAttachment(to task: TaskItem, fileName: String, contentType: String, data: Data) throws -> TaskAttachment {
        try AttachmentPolicy.validate(byteCount: data.count)
        let attachment = TaskAttachment(fileName: fileName, contentType: contentType, data: data)
        attachment.createdAt = environment.now()
        context.insert(attachment)
        attachment.task = task
        addActivity(.attachmentAdded, detail: fileName, to: task)
        try environment.save(changed: [task])
        return attachment
    }

    public func deleteAttachment(_ attachment: TaskAttachment) throws {
        let task = attachment.task
        context.delete(attachment)
        try environment.save(changed: task.map { [$0] } ?? [])
    }

    // MARK: Dependencies

    /// Marks `task` as blocked by `blocker`.
    /// - Throws: ``ProjectsError/selfDependency``, ``ProjectsError/dependencyAcrossProjects`` or
    ///   ``ProjectsError/dependencyCycle``.
    public func addDependency(_ task: TaskItem, blockedBy blocker: TaskItem) throws {
        guard task.id != blocker.id else { throw ProjectsError.selfDependency }
        guard let project = task.project, project.id == blocker.project?.id else {
            throw ProjectsError.dependencyAcrossProjects
        }
        var graph: [UUID: Set<UUID>] = [:]
        for item in project.taskList {
            graph[item.id] = Set((item.blockedBy ?? []).map(\.id))
        }
        guard !DependencyGraph.wouldCreateCycle(task: task.id, blockedBy: blocker.id, blockers: graph) else {
            throw ProjectsError.dependencyCycle
        }
        guard !(task.blockedBy ?? []).contains(where: { $0.id == blocker.id }) else { return }
        task.blockedBy = (task.blockedBy ?? []) + [blocker]
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    public func removeDependency(_ task: TaskItem, blockedBy blocker: TaskItem) throws {
        task.blockedBy = (task.blockedBy ?? []).filter { $0.id != blocker.id }
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    // MARK: Labels & custom fields

    public func toggleLabel(_ label: TaskLabel, on task: TaskItem) throws {
        if task.labelIDs.contains(label.id) {
            task.labels = (task.labels ?? []).filter { $0.id != label.id }
        } else {
            task.labels = (task.labels ?? []) + [label]
        }
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    /// Validates, normalises and stores a custom field value. An empty value removes it.
    public func setCustomFieldValue(_ raw: String, for definition: CustomFieldDefinition, on task: TaskItem) throws {
        let normalized = try CustomFieldCodec.normalize(
            raw,
            type: definition.type,
            options: definition.options,
            isRequired: definition.isRequired,
            fieldName: definition.name
        )
        if let existing = task.customFieldValue(for: definition) {
            if normalized.isEmpty {
                context.delete(existing)
            } else {
                existing.value = normalized
            }
        } else if !normalized.isEmpty {
            let value = CustomFieldValue(value: normalized)
            context.insert(value)
            value.definition = definition
            value.task = task
        }
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    // MARK: Internals

    var environmentContext: ModelContext { environment.context }

    func saveRestored(_ tasks: [TaskItem]) throws {
        try environment.save(changed: tasks)
    }

    private func ensureCanChangeStatus(of task: TaskItem, to status: TaskStatus) throws {
        guard task.canChangeStatus(to: status) else {
            throw ProjectsError.taskBlocked(taskTitle: task.title, blockerTitles: task.openBlockers.map(\.title))
        }
    }

    private func applyScheduling(of draft: TaskDraft, to task: TaskItem) {
        task.startDate = draft.startDate
        task.dueDate = draft.dueDate
        task.reminderDate = draft.reminderDate
        task.estimatedHours = draft.estimatedHours.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
        task.recurrence = draft.recurrence
    }

    private func labels(withIDs ids: Set<UUID>, in project: Project) -> [TaskLabel] {
        guard !ids.isEmpty else { return [] }
        return (project.workspace?.labels ?? []).filter { ids.contains($0.id) }
    }

    /// Moves a task to the end of `column`. The tasks left behind keep their keys; gaps are fine.
    private func placeAtEnd(_ task: TaskItem, of column: BoardColumn) {
        let source = task.column
        task.column = column
        task.order = SparseOrder.appendKey(after: (column.tasks ?? []).filter { $0.id != task.id }.map(\.order))
        if let source, source.id != column.id {
            addActivity(.moved, detail: column.name, to: task)
        }
    }

    /// Gives `task` the key for `index` among `others` (sorted, without the task). Renumbers the
    /// whole list only when there is no free key between the new neighbours.
    private func position(_ task: TaskItem, at index: Int, among others: [TaskItem]) {
        if let key = SparseOrder.key(insertingAt: index, between: others.map(\.order)) {
            task.order = key
            return
        }
        var list = others
        list.insert(task, at: min(max(index, 0), list.count))
        for (item, key) in zip(list, SparseOrder.renumbered(count: list.count)) {
            item.order = key
        }
    }

    /// Changes status, records activity and handles recurrence. Does not save.
    private func applyStatusChange(_ status: TaskStatus, to task: TaskItem) -> TaskItem? {
        let wasCompleted = task.isCompleted
        TaskStatusTransition.apply(status, to: task, now: environment.now())

        if status.isCompleted, !wasCompleted {
            addActivity(.completed, to: task)
            return spawnNextOccurrence(of: task)
        } else if wasCompleted, !status.isCompleted {
            addActivity(.reopened, to: task)
        } else {
            addActivity(.statusChanged, detail: status.rawValue, to: task)
        }
        return nil
    }

    /// Creates the next occurrence of a completed recurring task. The rule moves to the new task,
    /// so reopening and completing the old one again does not create duplicates.
    private func spawnNextOccurrence(of task: TaskItem) -> TaskItem? {
        guard let rule = task.recurrence, let project = task.project else { return nil }
        let now = environment.now()
        let base = task.dueDate ?? now
        guard let nextDue = rule.nextOccurrence(after: base, calendar: environment.calendar) else {
            task.recurrence = nil
            return nil
        }
        let column = project.firstColumn(for: .todo) ?? project.sortedColumns.first

        let next = TaskItem(title: task.title, details: task.details, status: column?.status ?? .todo, priority: task.priority)
        next.createdAt = now
        next.updatedAt = now
        context.insert(next)
        next.project = project
        next.column = column
        next.order = SparseOrder.appendKey(after: (column?.tasks ?? []).filter { $0.id != next.id }.map(\.order))
        next.dueDate = nextDue
        if let start = task.startDate {
            next.startDate = start.addingTimeInterval(nextDue.timeIntervalSince(base))
        }
        if let reminder = task.reminderDate {
            next.reminderDate = reminder.addingTimeInterval(nextDue.timeIntervalSince(base))
        }
        next.estimatedHours = task.estimatedHours
        next.recurrence = rule
        next.labels = task.labels ?? []
        next.involvedPeople = task.involvedPeople
        for (index, subtask) in task.sortedSubtasks.enumerated() {
            let copy = Subtask(title: subtask.title, order: index * SparseOrder.spacing)
            copy.createdAt = now
            context.insert(copy)
            copy.task = next
        }
        addActivity(.recurrenceSpawned, to: next)
        task.recurrence = nil
        return next
    }

    func addActivity(_ kind: ActivityKind, detail: String? = nil, to task: TaskItem) {
        let entry = ActivityEntry(kind: kind, detail: detail, createdAt: environment.now())
        context.insert(entry)
        entry.task = task
    }
}
