import Foundation
import SwiftData
import ProjectsCore

/// The editable properties of a task template.
public struct TemplateDraft: Equatable, Sendable {
    public var name: String
    public var category: TemplateCategory
    public var taskTitle: String
    public var taskDetails: String
    public var priority: TaskPriority
    public var estimatedHours: Double?
    public var subtaskTitles: [String]

    public init(
        name: String = "",
        category: TemplateCategory = .general,
        taskTitle: String = "",
        taskDetails: String = "",
        priority: TaskPriority = .medium,
        estimatedHours: Double? = nil,
        subtaskTitles: [String] = []
    ) {
        self.name = name
        self.category = category
        self.taskTitle = taskTitle
        self.taskDetails = taskDetails
        self.priority = priority
        self.estimatedHours = estimatedHours
        self.subtaskTitles = subtaskTitles
    }

    public init(template: TaskTemplate) {
        self.init(
            name: template.name,
            category: template.category,
            taskTitle: template.taskTitle,
            taskDetails: template.taskDetails,
            priority: template.priority,
            estimatedHours: template.estimatedHours,
            subtaskTitles: template.subtaskTitles
        )
    }
}

/// Reusable task blueprints, scoped to a workspace.
public final class TemplateService {
    private let environment: ServiceEnvironment
    private let taskService: TaskService

    public init(environment: ServiceEnvironment, taskService: TaskService) {
        self.environment = environment
        self.taskService = taskService
    }

    @discardableResult
    public func create(_ draft: TemplateDraft, in workspace: Workspace) throws -> TaskTemplate {
        let template = TaskTemplate(
            name: try Validation.name(draft.name, field: .templateName),
            category: draft.category,
            taskTitle: try Validation.name(draft.taskTitle, field: .taskTitle, maxLength: 200)
        )
        apply(draft, to: template)
        template.createdAt = environment.now()
        environment.context.insert(template)
        template.workspace = workspace
        try environment.save()
        return template
    }

    /// Creates a template from an existing task, including its subtasks.
    @discardableResult
    public func create(from task: TaskItem, name: String) throws -> TaskTemplate {
        guard let workspace = task.project?.workspace else { throw ProjectsError.notFound(.workspace) }
        let draft = TemplateDraft(
            name: name,
            category: .general,
            taskTitle: task.title,
            taskDetails: task.details,
            priority: task.priority,
            estimatedHours: task.estimatedHours,
            subtaskTitles: task.sortedSubtasks.map(\.title)
        )
        return try create(draft, in: workspace)
    }

    public func update(_ template: TaskTemplate, with draft: TemplateDraft) throws {
        template.name = try Validation.name(draft.name, field: .templateName)
        template.taskTitle = try Validation.name(draft.taskTitle, field: .taskTitle, maxLength: 200)
        apply(draft, to: template)
        try environment.save()
    }

    public func delete(_ template: TaskTemplate) throws {
        environment.context.delete(template)
        try environment.save()
    }

    /// Creates a task from the template in the given project.
    @discardableResult
    public func instantiate(_ template: TaskTemplate, in project: Project, dueDate: Date? = nil) throws -> TaskItem {
        let draft = TaskDraft(
            title: template.taskTitle,
            details: template.taskDetails,
            priority: template.priority,
            dueDate: dueDate,
            estimatedHours: template.estimatedHours
        )
        let task = try taskService.create(draft, in: project)
        for title in template.subtaskTitles {
            try taskService.addSubtask(to: task, title: title)
        }
        template.usageCount += 1
        try environment.save(changed: [task])
        return task
    }

    private func apply(_ draft: TemplateDraft, to template: TaskTemplate) {
        template.category = draft.category
        template.taskDetails = draft.taskDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        template.priority = draft.priority
        template.estimatedHours = draft.estimatedHours.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
        template.subtaskTitles = draft.subtaskTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
