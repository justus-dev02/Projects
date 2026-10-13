import Foundation

/// Every error that Projects surfaces to the user.
///
/// Lower layers translate framework errors (SwiftData, file system, JSON) into one of these cases
/// so that the UI can show a localized, actionable message instead of an internal description.
public enum ProjectsError: LocalizedError, Equatable, Sendable {
    public enum Field: String, Sendable {
        case workspaceName
        case projectName
        case taskTitle
        case columnName
        case labelName
        case templateName
        case customFieldName
        case subtaskTitle
        case comment
        case personName
        case question

        var title: String {
            switch self {
            case .workspaceName: String(localized: "Workspace name", bundle: .module, comment: "Form field")
            case .projectName: String(localized: "Project name", bundle: .module, comment: "Form field")
            case .taskTitle: String(localized: "Task title", bundle: .module, comment: "Form field")
            case .columnName: String(localized: "Column name", bundle: .module, comment: "Form field")
            case .labelName: String(localized: "Label name", bundle: .module, comment: "Form field")
            case .templateName: String(localized: "Template name", bundle: .module, comment: "Form field")
            case .customFieldName: String(localized: "Field name", bundle: .module, comment: "Form field")
            case .subtaskTitle: String(localized: "Subtask title", bundle: .module, comment: "Form field")
            case .comment: String(localized: "Comment", bundle: .module, comment: "Form field")
            case .personName: String(localized: "Name", bundle: .module, comment: "Form field: name of a person involved in a task")
            case .question: String(localized: "Question", bundle: .module, comment: "Form field: an open question about a task")
            }
        }
    }

    public enum Entity: String, Sendable {
        case workspace
        case project
        case task
        case column
        case template

        var title: String {
            switch self {
            case .workspace: String(localized: "Workspace", bundle: .module, comment: "Entity name")
            case .project: String(localized: "Project", bundle: .module, comment: "Entity name")
            case .task: String(localized: "Task", bundle: .module, comment: "Entity name")
            case .column: String(localized: "Column", bundle: .module, comment: "Entity name")
            case .template: String(localized: "Template", bundle: .module, comment: "Entity name")
            }
        }
    }

    case emptyField(Field)
    case fieldTooLong(Field, maxLength: Int)
    case notFound(Entity)
    case cannotDeleteLastColumn
    case selfDependency
    case dependencyCycle
    case dependencyAcrossProjects
    /// The task cannot leave "To Do" while the listed tasks are not done.
    case taskBlocked(taskTitle: String, blockerTitles: [String])
    case invalidCustomFieldValue(fieldName: String)
    case requiredCustomFieldMissing(fieldName: String)
    case customFieldNeedsOptions
    case attachmentTooLarge(maxBytes: Int)
    case unsupportedBackupVersion(Int)
    case corruptBackup
    case persistenceFailed
    case storeUnavailable

    public var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            let name = field.title
            return String(localized: "\(name) must not be empty.", bundle: .module, comment: "Validation error")
        case .fieldTooLong(let field, let maxLength):
            let name = field.title
            return String(
                localized: "\(name) must not be longer than \(maxLength) characters.",
                bundle: .module,
                comment: "Validation error"
            )
        case .notFound(let entity):
            let name = entity.title
            return String(localized: "\(name) could not be found.", bundle: .module, comment: "Error")
        case .cannotDeleteLastColumn:
            return String(
                localized: "A project needs at least one column.",
                bundle: .module,
                comment: "Error"
            )
        case .selfDependency:
            return String(localized: "A task cannot depend on itself.", bundle: .module, comment: "Error")
        case .dependencyCycle:
            return String(
                localized: "This dependency would create a cycle.",
                bundle: .module,
                comment: "Error"
            )
        case .dependencyAcrossProjects:
            return String(
                localized: "Dependencies are only possible within the same project.",
                bundle: .module,
                comment: "Error"
            )
        case .taskBlocked(let taskTitle, let blockerTitles):
            let blockers = blockerTitles.map { "“\($0)”" }.formatted(.list(type: .and))
            return String(
                localized: "“\(taskTitle)” is waiting for \(blockers).",
                bundle: .module,
                comment: "Error: a blocked task cannot be started. Second argument is a list of task titles"
            )
        case .invalidCustomFieldValue(let fieldName):
            return String(
                localized: "The value for “\(fieldName)” is not valid.",
                bundle: .module,
                comment: "Error"
            )
        case .requiredCustomFieldMissing(let fieldName):
            return String(localized: "“\(fieldName)” is required.", bundle: .module, comment: "Error")
        case .customFieldNeedsOptions:
            return String(
                localized: "A choice field needs at least one option.",
                bundle: .module,
                comment: "Error"
            )
        case .attachmentTooLarge(let maxBytes):
            let size = Int64(maxBytes).formatted(.byteCount(style: .memory))
            return String(
                localized: "Attachments can be at most \(size).",
                bundle: .module,
                comment: "Error"
            )
        case .unsupportedBackupVersion(let version):
            return String(
                localized: "This backup was created with a newer version of Projects (format \(version)).",
                bundle: .module,
                comment: "Error"
            )
        case .corruptBackup:
            return String(localized: "The backup file is damaged or not a Projects backup.", bundle: .module, comment: "Error")
        case .persistenceFailed:
            return String(localized: "Your changes could not be saved.", bundle: .module, comment: "Error")
        case .storeUnavailable:
            return String(localized: "The database could not be opened.", bundle: .module, comment: "Error")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .persistenceFailed:
            String(localized: "Please try again. If the problem persists, restart the app.", bundle: .module, comment: "Recovery")
        case .taskBlocked:
            String(
                localized: "Finish the blocking tasks first, or remove them under “Blocked By”.",
                bundle: .module,
                comment: "Recovery"
            )
        case .unsupportedBackupVersion:
            String(localized: "Update Projects and try again.", bundle: .module, comment: "Recovery")
        case .storeUnavailable:
            String(
                localized: "You can restore a backup or reset the local database in Settings.",
                bundle: .module,
                comment: "Recovery"
            )
        default:
            nil
        }
    }
}
