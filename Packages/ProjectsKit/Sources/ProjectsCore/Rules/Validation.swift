import Foundation

/// Input validation shared by every form and service.
public enum Validation {
    public static let maxNameLength = 120
    public static let maxDetailsLength = 10_000

    /// Trims whitespace and checks that the value is neither empty nor too long.
    /// - Returns: The trimmed value.
    public static func name(
        _ raw: String,
        field: ProjectsError.Field,
        maxLength: Int = maxNameLength
    ) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectsError.emptyField(field)
        }
        guard trimmed.count <= maxLength else {
            throw ProjectsError.fieldTooLong(field, maxLength: maxLength)
        }
        return trimmed
    }

    /// Trims optional free text. Returns an empty string for whitespace-only input.
    public static func details(_ raw: String, field: ProjectsError.Field) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= maxDetailsLength else {
            throw ProjectsError.fieldTooLong(field, maxLength: maxDetailsLength)
        }
        return trimmed
    }
}
