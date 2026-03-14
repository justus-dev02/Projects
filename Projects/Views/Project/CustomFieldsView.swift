//
//  CustomFieldsView.swift
//  Projects
//
//  TaskFlow - Custom Fields Management
//

import SwiftUI
import SwiftData // FIXED: Required for modelContext.save()
import Combine   // FIXED: Required for ObservableObject and @Published

// MARK: - Custom Fields View
struct CustomFieldsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CustomFieldsViewModel
    
    let projectId: String
    
    @State private var showingAddField = false
    @State private var selectedField: CustomFieldDefinition?
    
    init(projectId: String, dataService: DataService) {
        self.projectId = projectId
        _viewModel = StateObject(wrappedValue: CustomFieldsViewModel(dataService: dataService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fields List
                fieldsList
            }
            .navigationTitle("Custom Fields")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddField = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddField) {
                AddCustomFieldView(projectId: projectId, viewModel: viewModel) {
                    showingAddField = false
                    viewModel.loadFields()
                }
            }
            .task {
                viewModel.loadFields()
            }
        }
    }
    
    // MARK: - Fields List
    private var fieldsList: some View {
        Group {
            if viewModel.fields.isEmpty {
                EmptyCustomFieldsView {
                    showingAddField = true
                }
            } else {
                List {
                    ForEach(viewModel.fields.sorted { $0.order < $1.order }, id: \.id) { field in
                        CustomFieldRow(
                            field: field,
                            onEdit: {
                                // Edit field
                            },
                            onDelete: {
                                viewModel.deleteField(field)
                            }
                        )
                    }
                    .onMove { indices, newOffset in
                        viewModel.reorderFields(from: indices, to: newOffset)
                    }
                }
            }
        }
    }
}

// MARK: - Custom Field Row
struct CustomFieldRow: View {
    let field: CustomFieldDefinition
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: field.color ?? "#2D5BFF").opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: field.icon ?? field.fieldTypeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: field.color ?? "#2D5BFF"))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(field.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    if field.isRequired {
                        Text("Required")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TaskFlowColors.warning.opacity(0.15))
                            .foregroundColor(TaskFlowColors.warning)
                            .cornerRadius(TaskFlowRadius.small)
                    }
                }
                
                Text(field.fieldTypeDisplayName)
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: TaskFlowSpacing.small) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.error)
                }
            }
        }
        .padding(.vertical, TaskFlowSpacing.small)
    }
}

// MARK: - Empty Custom Fields View
struct EmptyCustomFieldsView: View {
    let onCreateField: () -> Void
    
    var body: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)
            
            Text("No Custom Fields")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            Text("Add custom fields to track\nproject-specific information")
                .font(.system(size: 13))
                .foregroundColor(TaskFlowColors.textSecondary)
                .multilineTextAlignment(.center)
            
            TFButton(title: "Add Custom Field", style: .primary, icon: "plus") {
                onCreateField()
            }
        }
        .padding(.vertical, TaskFlowSpacing.xHuge * 2)
    }
}

// MARK: - Add Custom Field View
struct AddCustomFieldView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let projectId: String
    @ObservedObject var viewModel: CustomFieldsViewModel
    let onFieldAdded: () -> Void
    
    @State private var name: String = ""
    @State private var selectedType: String = "text"
    @State private var isRequired: Bool = false
    @State private var defaultValue: String = ""
    @State private var options: String = ""
    @State private var selectedColor: String = "#2D5BFF"
    @State private var showingTypePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section {
                    TFTextField(
                        title: "Field Name",
                        placeholder: "Enter field name",
                        text: $name
                    )
                }
                
                // Type
                Section {
                    Button(action: {
                        showingTypePicker = true
                    }) {
                        HStack {
                            Text("Field Type")
                                .foregroundColor(TaskFlowColors.textPrimary)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text(fieldTypeDisplayName)
                                    .foregroundColor(TaskFlowColors.textSecondary)
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(TaskFlowColors.textTertiary)
                            }
                        }
                    }
                }
                
                // Required toggle
                Section {
                    Toggle("Required Field", isOn: $isRequired)
                }
                
                // Default Value
                Section {
                    TFTextField(
                        title: "Default Value (Optional)",
                        placeholder: "Enter default value",
                        text: $defaultValue
                    )
                }
                
                // Options (for dropdown/multi-select)
                if selectedType == "dropdown" || selectedType == "multiSelect" {
                    Section {
                        TFTextField(
                            title: "Options",
                            placeholder: "Option 1, Option 2, Option 3",
                            text: $options,
                            multiline: true,
                            minLineCount: 3
                        )
                        
                        Text("Separate options with commas")
                            .font(.system(size: 11))
                            .foregroundColor(TaskFlowColors.textTertiary)
                    }
                }
                
                // Color
                Section {
                    Text("Color")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    TFColorPicker(selectedColor: $selectedColor, columns: 8)
                }
            }
            .navigationTitle("New Custom Field")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createField()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .confirmationDialog("Select Field Type", isPresented: $showingTypePicker) {
                ForEach(CustomFieldDefinition.FieldType.allCases) { type in
                    Button(type.rawValue) {
                        selectedType = type.rawValue.lowercased()
                    }
                }
            }
        }
    }
    
    private var fieldTypeDisplayName: String {
        CustomFieldDefinition.FieldType(rawValue: selectedType)?.rawValue ?? selectedType.capitalized
    }
    
    private func createField() {
        let field = CustomFieldDefinition(
            name: name,
            fieldType: selectedType,
            options: options.isEmpty ? nil : options, // FIXED: Moved `options` above `isRequired`
            defaultValue: defaultValue.isEmpty ? nil : defaultValue, isRequired: isRequired,
            color: selectedColor
        )
        
        modelContext.insert(field)
        
        do {
            try modelContext.save()
            onFieldAdded()
            dismiss()
        } catch {
            print("Error creating field: \(error)")
        }
    }
}

// MARK: - Custom Fields View Model
@MainActor
class CustomFieldsViewModel: ObservableObject {
    @Published var fields: [CustomFieldDefinition] = []
    @Published var isLoading = false
    
    private let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func loadFields() {
        do {
            let predicate = #Predicate<CustomFieldDefinition> { _ in true }
            let sortDescriptor = [SortDescriptor<CustomFieldDefinition>(\.order)]
            fields = try dataService.fetch(CustomFieldDefinition.self, filter: sortDescriptor, predicate: predicate)
        } catch {
            print("Error loading fields: \(error)")
        }
    }
    
    func deleteField(_ field: CustomFieldDefinition) {
        dataService.delete(field)
        try? dataService.save()
        loadFields()
    }
    
    func reorderFields(from indices: IndexSet, to newOffset: Int) {
        // Update order values
        var sortedFields = fields.sorted { $0.order < $1.order }
        
        for index in indices {
            let field = sortedFields[index]
            sortedFields.remove(at: index)
            sortedFields.insert(field, at: newOffset)
        }
        
        for (index, field) in sortedFields.enumerated() {
            field.order = index
        }
        
        try? dataService.save()
        loadFields()
    }
}

// MARK: - Field Type Extension
extension CustomFieldDefinition {
    var fieldTypeIcon: String {
        CustomFieldDefinition.FieldType(rawValue: fieldType)?.icon ?? "text.alignleft"
    }
    
    var fieldTypeDisplayName: String {
        CustomFieldDefinition.FieldType(rawValue: fieldType)?.rawValue ?? fieldType.capitalized
    }
}

// MARK: - Preview
#Preview("Custom Fields") {
    CustomFieldsView(projectId: "test", dataService: DataService())
}
