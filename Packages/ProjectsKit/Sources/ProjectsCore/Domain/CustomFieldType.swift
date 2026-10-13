import Foundation

/// The kind of value a project-specific custom field holds.
///
/// Values are persisted as strings in a locale-independent format (see ``CustomFieldCodec``),
/// so a value written on a German device reads back identically on an English one.
public enum CustomFieldType: String, CaseIterable, Codable, Sendable, Identifiable {
    case text
    case number
    case date
    case checkbox
    case choice
    case url

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .text: String(localized: "Text", bundle: .module, comment: "Custom field type")
        case .number: String(localized: "Number", bundle: .module, comment: "Custom field type")
        case .date: String(localized: "Date", bundle: .module, comment: "Custom field type")
        case .checkbox: String(localized: "Checkbox", bundle: .module, comment: "Custom field type")
        case .choice: String(localized: "Choice", bundle: .module, comment: "Custom field type")
        case .url: String(localized: "Link", bundle: .module, comment: "Custom field type")
        }
    }

    public var symbolName: String {
        switch self {
        case .text: "textformat"
        case .number: "number"
        case .date: "calendar"
        case .checkbox: "checkmark.square"
        case .choice: "list.bullet.circle"
        case .url: "link"
        }
    }

    public var requiresOptions: Bool { self == .choice }
}

/// Converts typed custom field values to and from their persisted string form.
public enum CustomFieldCodec {
    public static func encode(number: Double) -> String {
        // `description` is locale independent ("1.5", never "1,5").
        number.description
    }

    public static func decodeNumber(_ raw: String) -> Double? {
        Double(raw)
    }

    public static func encode(date: Date) -> String {
        date.formatted(.iso8601)
    }

    public static func decodeDate(_ raw: String) -> Date? {
        try? Date(raw, strategy: .iso8601)
    }

    public static func encode(bool: Bool) -> String {
        bool ? "true" : "false"
    }

    public static func decodeBool(_ raw: String) -> Bool {
        raw == "true"
    }

    /// Validates and normalises a raw value for the given field.
    ///
    /// An empty string always means "no value" and is valid unless the field is required.
    /// - Throws: ``ProjectsError/invalidCustomFieldValue(fieldName:)`` or
    ///   ``ProjectsError/requiredCustomFieldMissing(fieldName:)``.
    public static func normalize(
        _ raw: String,
        type: CustomFieldType,
        options: [String],
        isRequired: Bool,
        fieldName: String
    ) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            if isRequired {
                throw ProjectsError.requiredCustomFieldMissing(fieldName: fieldName)
            }
            return ""
        }

        switch type {
        case .text:
            return value
        case .number:
            guard let number = decodeNumber(value), number.isFinite else {
                throw ProjectsError.invalidCustomFieldValue(fieldName: fieldName)
            }
            return encode(number: number)
        case .date:
            guard decodeDate(value) != nil else {
                throw ProjectsError.invalidCustomFieldValue(fieldName: fieldName)
            }
            return value
        case .checkbox:
            guard value == "true" || value == "false" else {
                throw ProjectsError.invalidCustomFieldValue(fieldName: fieldName)
            }
            return value
        case .choice:
            guard options.contains(value) else {
                throw ProjectsError.invalidCustomFieldValue(fieldName: fieldName)
            }
            return value
        case .url:
            guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme) else {
                throw ProjectsError.invalidCustomFieldValue(fieldName: fieldName)
            }
            return url.absoluteString
        }
    }
}
