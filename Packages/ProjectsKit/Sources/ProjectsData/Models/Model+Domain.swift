import Foundation
import ProjectsCore

// Typed accessors on top of the raw persisted values. SwiftData predicates and sort descriptors
// work on the `…Raw` properties; everything else uses these typed properties.

extension Workspace {
    public var projectList: [Project] {
        (projects ?? []).sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    public var activeProjects: [Project] {
        projectList.filter { !$0.isArchived }
    }

    public var sortedLabels: [TaskLabel] {
        (labels ?? []).sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    public var sortedTemplates: [TaskTemplate] {
        (templates ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public var deepLink: DeepLink { .workspace(id) }
}

extension Project {
    public var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    public var sortedColumns: [BoardColumn] {
        (columns ?? []).sorted { $0.order < $1.order }
    }

    public var taskList: [TaskItem] {
        tasks ?? []
    }

    public var sortedCustomFields: [CustomFieldDefinition] {
        (customFields ?? []).sorted { $0.order < $1.order }
    }

    /// The first column (in board order) that represents `status`.
    public func firstColumn(for status: TaskStatus) -> BoardColumn? {
        sortedColumns.first { $0.status == status }
    }

    public func statistics(now: Date, calendar: Calendar) -> TaskStatistics {
        TaskStatistics(tasks: taskList.map(\.snapshot), now: now, calendar: calendar)
    }

    public var deepLink: DeepLink { .project(id) }
}

extension BoardColumn {
    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    public var sortedTasks: [TaskItem] {
        (tasks ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }
}

extension TaskItem: TaskFilterable {
    public var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }

    public var isCompleted: Bool { status.isCompleted }

    public var labelIDs: Set<UUID> {
        Set((labels ?? []).map(\.id))
    }

    public var sortedLabels: [TaskLabel] {
        (labels ?? []).sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    public var sortedSubtasks: [Subtask] {
        (subtasks ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    public var sortedComments: [TaskComment] {
        (comments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    public var sortedAttachments: [TaskAttachment] {
        (attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    public var sortedActivity: [ActivityEntry] {
        (activity ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    public var blockers: [TaskItem] {
        (blockedBy ?? []).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    public var completedSubtaskCount: Int {
        (subtasks ?? []).count(where: \.isCompleted)
    }

    public var subtaskCount: Int {
        subtasks?.count ?? 0
    }

    /// `true` while at least one blocking task is not done.
    public var isBlocked: Bool {
        (blockedBy ?? []).contains { !$0.isCompleted }
    }

    /// The blocking tasks that are not done yet, sorted by title.
    public var openBlockers: [TaskItem] {
        blockers.filter { !$0.isCompleted }
    }

    /// Tasks that wait for this one, sorted by title.
    public var dependents: [TaskItem] {
        (blocking ?? []).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// A blocked task may stay in or go back to "To Do"; every other status needs its blockers done.
    public func canChangeStatus(to status: TaskStatus) -> Bool {
        status == .todo || status == self.status || !isBlocked
    }

    public var sortedQuestions: [TaskQuestion] {
        (questions ?? []).sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    public var openQuestionCount: Int {
        (questions ?? []).count { !$0.isAnswered }
    }

    public var hasComments: Bool {
        !(comments ?? []).isEmpty
    }

    /// `true` when a comment written on another device has not been viewed yet.
    /// - Parameter installation: The installation the app is running in.
    public func hasUnreadComments(in installation: Installation) -> Bool {
        (comments ?? []).contains { $0.isUnread(in: installation) }
    }

    public func isOverdue(now: Date) -> Bool {
        snapshot.isOverdue(now: now)
    }

    public func customFieldValue(for definition: CustomFieldDefinition) -> CustomFieldValue? {
        (customFieldValues ?? []).first { $0.definition?.id == definition.id }
    }

    public var snapshot: TaskSnapshot {
        TaskSnapshot(status: status, priority: priority, dueDate: dueDate, completedAt: completedAt)
    }

    public var deepLink: DeepLink { .task(id) }
}

extension TaskComment {
    /// A comment is unread when another installation wrote it after this one was installed and it
    /// has not been viewed yet. Comments from before version 2 (no author) are never unread.
    public func isUnread(in installation: Installation) -> Bool {
        !isRead && !authorDeviceID.isEmpty && authorDeviceID != installation.id
            && createdAt > installation.installedAt
    }
}

extension ActivityEntry {
    public var kind: ActivityKind {
        ActivityKind(rawValue: kindRaw) ?? .created
    }

    public var message: String {
        kind.message(detail: detail)
    }
}

extension CustomFieldDefinition {
    public var type: CustomFieldType {
        get { CustomFieldType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }
}

extension TaskTemplate {
    public var category: TemplateCategory {
        get { TemplateCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    public var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
}
