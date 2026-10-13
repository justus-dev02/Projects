import Foundation
import SwiftData
import ProjectsCore

extension TaskItem {
    /// The task as a value type, used by the JSON backup and by "Undo delete".
    var backupRecord: BackupDocument.TaskRecord {
        BackupDocument.TaskRecord(
            id: id,
            title: title,
            details: details,
            status: status,
            priority: priority,
            columnID: column?.id,
            order: order,
            startDate: startDate,
            dueDate: dueDate,
            completedAt: completedAt,
            reminderDate: reminderDate,
            estimatedHours: estimatedHours,
            recurrence: recurrence,
            createdAt: createdAt,
            updatedAt: updatedAt,
            labelIDs: sortedLabels.map(\.id),
            blockedByIDs: blockers.map(\.id),
            subtasks: sortedSubtasks.map { .init(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, order: $0.order) },
            comments: sortedComments.map {
                .init(
                    id: $0.id, text: $0.text, createdAt: $0.createdAt, updatedAt: $0.updatedAt,
                    authorDeviceID: $0.authorDeviceID, isRead: $0.isRead
                )
            },
            customFieldValues: (customFieldValues ?? []).compactMap { value in
                value.definition.map { .init(fieldID: $0.id, value: value.value) }
            },
            involvedPeople: involvedPeople,
            questions: sortedQuestions.map {
                .init(id: $0.id, text: $0.text, isAnswered: $0.isAnswered, answeredAt: $0.answeredAt, order: $0.order, createdAt: $0.createdAt)
            }
        )
    }
}

extension TaskItem {
    /// Applies the parts of a record that both the backup import and "Undo delete" restore the
    /// same way: people, comments and questions. The task must already be inserted.
    func restoreChildren(from record: BackupDocument.TaskRecord, in context: ModelContext) {
        involvedPeople = (record.involvedPeople ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for commentRecord in record.comments {
            let comment = TaskComment(text: commentRecord.text)
            comment.id = commentRecord.id
            comment.createdAt = commentRecord.createdAt
            comment.updatedAt = commentRecord.updatedAt
            comment.authorDeviceID = commentRecord.authorDeviceID ?? ""
            comment.isRead = commentRecord.isRead ?? false
            context.insert(comment)
            comment.task = self
        }
        for questionRecord in record.questions ?? [] {
            let question = TaskQuestion(text: questionRecord.text, order: questionRecord.order)
            question.id = questionRecord.id
            question.isAnswered = questionRecord.isAnswered
            question.answeredAt = questionRecord.answeredAt
            question.createdAt = questionRecord.createdAt
            context.insert(question)
            question.task = self
        }
    }
}
