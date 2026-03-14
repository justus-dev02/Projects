//
//  CustomField.swift
//  Projects
//
//  TaskFlow - Custom Field Model
//

import Foundation
import SwiftData

/// Model for custom field definitions at project/workspace level
@Model
final class CustomFieldDefinition {
    @Attribute(.unique) var id: String
    var name: String
    var fieldType: String
    var options: String?  // JSON array for select/multi-select options
    var defaultValue: String?
    var isRequired: Bool
    var order: Int
    var color: String?
    var icon: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var project: Project?
    @Relationship(deleteRule: .cascade) var values: [CustomFieldValue]?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        fieldType: String = "text",
        options: String? = nil,
        defaultValue: String? = nil,
        isRequired: Bool = false,
        order: Int = 0,
        color: String? = nil,
        icon: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fieldType = fieldType
        self.options = options
        self.defaultValue = defaultValue
        self.isRequired = isRequired
        self.order = order
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Model for custom field values on individual tasks
@Model
final class CustomFieldValue {
    @Attribute(.unique) var id: String
    var value: String  // Stored as JSON for complex types
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var definition: CustomFieldDefinition?
    @Relationship(deleteRule: .cascade) var task: Task?
    
    init(
        id: String = UUID().uuidString,
        value: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.value = value
        self.updatedAt = updatedAt
    }
}

// MARK: - Field Type
extension CustomFieldDefinition {
    enum FieldType: String, CaseIterable, Identifiable {
        case text = "Text"
        case number = "Number"
        case date = "Date"
        case dropdown = "Dropdown"
        case multiSelect = "Multi-select"
        case checkbox = "Checkbox"
        case url = "URL"
        case email = "Email"
        case phone = "Phone"
        case currency = "Currency"
        case percent = "Percentage"
        case rating = "Rating"
        case person = "Person"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .text: return "text.alignleft"
            case .number: return "number"
            case .date: return "calendar"
            case .dropdown: return "chevron.down.circle"
            case .multiSelect: return "checkmark.seal"
            case .checkbox: return "checkmark.square"
            case .url: return "link"
            case .email: return "envelope"
            case .phone: return "phone"
            case .currency: return "dollarsign.circle"
            case .percent: return "percent"
            case .rating: return "star.fill"
            case .person: return "person.fill"
            }
        }
        
        var isMultiValue: Bool {
            self == .multiSelect
        }
        
        var requiresOptions: Bool {
            self == .dropdown || self == .multiSelect
        }
    }
}

// MARK: - Value Parsing
extension CustomFieldValue {
    var textValue: String? {
        guard !value.isEmpty else { return nil }
        return value
    }
    
    var numberValue: Double? {
        guard !value.isEmpty else { return nil }
        return Double(value)
    }
    
    var dateValue: Date? {
        guard !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }
    
    var boolValue: Bool? {
        guard !value.isEmpty else { return nil }
        return value.lowercased() == "true" || value == "1"
    }
    
    var arrayValue: [String]? {
        guard !value.isEmpty else { return nil }
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    var urlValue: URL? {
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }
}

// MARK: - Computed Properties
extension CustomFieldDefinition {
    var parsedOptions: [String]? {
        guard let options = options else { return nil }
        guard let data = options.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
    
    var valueCount: Int {
        values?.count ?? 0
    }

    var populatedTasksCount: Int {
        guard let values = values else { return 0 }
        return values.filter { !$0.value.isEmpty }.count
    }
}
