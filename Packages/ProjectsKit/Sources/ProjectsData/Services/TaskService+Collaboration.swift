import Foundation
import SwiftData
import ProjectsCore

/// Comments, the people involved in a task and open questions about it.
extension TaskService {
    // MARK: Comments

    @discardableResult
    public func addComment(to task: TaskItem, text: String) throws -> TaskComment {
        let comment = TaskComment(text: try Validation.name(text, field: .comment, maxLength: Validation.maxDetailsLength))
        let now = environment.now()
        comment.createdAt = now
        comment.updatedAt = now
        comment.authorDeviceID = environment.installation.id
        context.insert(comment)
        comment.task = task
        addActivity(.commentAdded, to: task)
        try environment.save(changed: [task])
        return comment
    }

    public func editComment(_ comment: TaskComment, text: String) throws {
        comment.text = try Validation.name(text, field: .comment, maxLength: Validation.maxDetailsLength)
        comment.updatedAt = environment.now()
        try environment.save(changed: comment.task.map { [$0] } ?? [])
    }

    /// Marks comments that arrived from other devices as read. Called when the task is viewed.
    /// Does not touch `updatedAt`, because reading is not an edit.
    public func markCommentsRead(of task: TaskItem) throws {
        let unread = (task.comments ?? []).filter { $0.isUnread(in: environment.installation) }
        guard !unread.isEmpty else { return }
        for comment in unread {
            comment.isRead = true
        }
        try environment.save()
    }

    /// Deletes only the comment. The task is not affected.
    public func deleteComment(_ comment: TaskComment) throws {
        let task = comment.task
        context.delete(comment)
        try environment.save(changed: task.map { [$0] } ?? [])
    }

    // MARK: People

    /// Adds a person by name. Names are trimmed; a name already on the task (ignoring case) is not
    /// added twice.
    public func addPerson(named name: String, to task: TaskItem) throws {
        task.involvedPeople = try Self.normalizedPeople(task.involvedPeople + [name])
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    public func removePerson(named name: String, from task: TaskItem) throws {
        task.involvedPeople = task.involvedPeople.filter { $0 != name }
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
    }

    /// Validates names and removes duplicates, keeping the first spelling.
    static func normalizedPeople(_ names: [String]) throws -> [String] {
        var result: [String] = []
        for name in names {
            let trimmed = try Validation.name(name, field: .personName, maxLength: maxPersonNameLength)
            if !result.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
                result.append(trimmed)
            }
        }
        return result
    }

    public static let maxPersonNameLength = 80

    // MARK: Questions

    @discardableResult
    public func addQuestion(to task: TaskItem, text: String) throws -> TaskQuestion {
        let question = TaskQuestion(
            text: try Validation.name(text, field: .question, maxLength: 500),
            order: SparseOrder.appendKey(after: (task.questions ?? []).map(\.order))
        )
        question.createdAt = environment.now()
        context.insert(question)
        question.task = task
        task.updatedAt = environment.now()
        try environment.save(changed: [task])
        return question
    }

    public func toggleQuestion(_ question: TaskQuestion) throws {
        question.isAnswered.toggle()
        question.answeredAt = question.isAnswered ? environment.now() : nil
        question.task?.updatedAt = environment.now()
        try environment.save(changed: question.task.map { [$0] } ?? [])
    }

    public func editQuestion(_ question: TaskQuestion, text: String) throws {
        question.text = try Validation.name(text, field: .question, maxLength: 500)
        try environment.save(changed: question.task.map { [$0] } ?? [])
    }

    public func deleteQuestion(_ question: TaskQuestion) throws {
        let task = question.task
        context.delete(question)
        try environment.save(changed: task.map { [$0] } ?? [])
    }
}
