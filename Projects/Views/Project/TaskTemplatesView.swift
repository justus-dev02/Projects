//
//  TaskTemplatesView.swift
//  Projects
//
//  TaskFlow - Task Templates Management
//

import SwiftUI
import SwiftData // FIXED: Added missing import
import Combine   // FIXED: Added missing import

// MARK: - Task Templates View
struct TaskTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: TaskTemplatesViewModel
    
    let projectId: String?
    
    @State private var showingCreateTemplate = false
    @State private var selectedTemplate: TaskTemplate?
    @State private var showingApplyTemplate = false
    
    init(projectId: String? = nil, dataService: DataService) {
        self.projectId = projectId
        _viewModel = StateObject(wrappedValue: TaskTemplatesViewModel(dataService: dataService))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilter
                
                Divider()
                
                // Templates Grid
                templatesGrid
            }
            .navigationTitle("Templates")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingCreateTemplate = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTemplate) {
                CreateTemplateView(viewModel: viewModel) {
                    showingCreateTemplate = false
                    viewModel.loadTemplates()
                }
            }
            .task {
                viewModel.loadTemplates(projectId: projectId)
            }
        }
    }
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskFlowSpacing.small) {
                ForEach(TaskTemplate.TemplateCategory.allCases) { category in
                    TemplateFilterChip(
                        title: category.rawValue,
                        icon: category.icon,
                        color: Color(hex: category.color),
                        isSelected: viewModel.selectedCategory == category.rawValue
                    ) {
                        viewModel.selectedCategory = category.rawValue
                        viewModel.loadTemplates(projectId: projectId)
                    }
                }
            }
            .padding()
        }
        .background(TaskFlowColors.background)
    }
    
    // MARK: - Templates Grid
    private var templatesGrid: some View {
        Group {
            if viewModel.templates.isEmpty {
                EmptyTemplatesView {
                    showingCreateTemplate = true
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: TaskFlowSpacing.large) {
                        ForEach(viewModel.templates, id: \.id) { template in
                            TemplateCard(
                                template: template,
                                onUse: {
                                    selectedTemplate = template
                                    showingApplyTemplate = true
                                },
                                onEdit: {
                                    // Edit template
                                },
                                onDelete: {
                                    viewModel.deleteTemplate(template)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct TemplateFilterChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, TaskFlowSpacing.medium)
            .padding(.vertical, TaskFlowSpacing.small)
            .background(isSelected ? color.opacity(0.15) : TaskFlowColors.surface)
            .foregroundColor(isSelected ? color : TaskFlowColors.textSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: TaskFlowRadius.small)
                    .stroke(isSelected ? color : TaskFlowColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: TaskTemplate
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: template.color).opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: template.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: template.color))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(template.category)
                        .font(.system(size: 11))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                Spacer()
                
                // Usage count
                VStack(spacing: 0) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8))
                        .foregroundColor(TaskFlowColors.textTertiary)
                    
                    Text("\(template.usageCount)")
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
            
            // Description
            if let description = template.templateDescription {
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .lineLimit(2)
            }
            
            Divider()
            
            // Footer
            HStack(spacing: TaskFlowSpacing.small) {
                // Subtasks count
                if let subtasks = template.parsedSubtasks, !subtasks.isEmpty {
                    SwiftUI.Label("\(subtasks.count)", systemImage: "checkmark.seal") // FIXED: Added SwiftUI. prefix
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                Spacer()
                
                // Actions
                Menu {
                    Button(action: onUse) {
                        SwiftUI.Label("Use Template", systemImage: "plus") // FIXED: Added SwiftUI. prefix
                    }
                    
                    Button(action: onEdit) {
                        SwiftUI.Label("Edit", systemImage: "pencil") // FIXED: Added SwiftUI. prefix
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        SwiftUI.Label("Delete", systemImage: "trash") // FIXED: Added SwiftUI. prefix
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
        }
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
}

// MARK: - Empty Templates View
struct EmptyTemplatesView: View {
    let onCreateTemplate: () -> Void
    
    var body: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Image(systemName: "doc.text.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(TaskFlowColors.textTertiary)
            
            Text("No Templates")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            Text("Create templates for tasks\nyou frequently create")
                .font(.system(size: 13))
                .foregroundColor(TaskFlowColors.textSecondary)
                .multilineTextAlignment(.center)
            
            TFButton(title: "Create Template", style: .primary, icon: "plus") {
                onCreateTemplate()
            }
        }
        .padding(.vertical, TaskFlowSpacing.xHuge * 2)
    }
}

// MARK: - Create Template View
struct CreateTemplateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject var viewModel: TaskTemplatesViewModel
    let onTemplateCreated: () -> Void
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedCategory: String = "General"
    @State private var title: String = ""
    @State private var taskDescription: String = ""
    @State private var selectedPriority: String = "medium"
    @State private var estimatedHours: String = ""
    @State private var subtaskTitles: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Template Info
                Section {
                    TFTextField(
                        title: "Template Name",
                        placeholder: "e.g., Bug Report Template",
                        text: $name
                    )
                    
                    TFTextField(
                        title: "Description",
                        placeholder: "Describe when to use this template",
                        text: $description,
                        multiline: true,
                        minLineCount: 2
                    )
                    
                    // Category picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TaskTemplate.TemplateCategory.allCases) { category in
                            Text(category.rawValue).tag(category.rawValue)
                        }
                    }
                }
                
                // Task Content
                Section {
                    TFTextField(
                        title: "Default Title",
                        placeholder: "Task title template",
                        text: $title
                    )
                    
                    TFTextField(
                        title: "Default Description",
                        placeholder: "Task description template",
                        text: $taskDescription,
                        multiline: true,
                        minLineCount: 3
                    )
                    
                    // Priority picker
                    Picker("Priority", selection: $selectedPriority) {
                        ForEach(Task.Priority.allCases) { priority in
                            Text(priority.rawValue).tag(priority.rawValue.lowercased())
                        }
                    }
                    
                    TFTextField(
                        title: "Estimated Hours (Optional)",
                        placeholder: "e.g., 4",
                        text: $estimatedHours
                    )
                }
                
                // Subtasks
                Section {
                    TFTextField(
                        title: "Default Subtasks",
                        placeholder: "One subtask per line",
                        text: $subtaskTitles,
                        multiline: true,
                        minLineCount: 4
                    )
                    
                    Text("Enter each subtask on a new line")
                        .font(.system(size: 11))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
            .navigationTitle("New Template")
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
                        createTemplate()
                    }
                    .disabled(name.isEmpty || title.isEmpty)
                }
            }
        }
    }
    
    private func createTemplate() {
        // Parse subtasks
        let subtaskList = subtaskTitles
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let subtaskTemplates = subtaskList.enumerated().map { index, title in
            TaskTemplate.SubtaskTemplate(title: title.trimmingCharacters(in: .whitespaces), order: index)
        }
        
        let template = TaskTemplate(
            name: name,
            templateDescription: description.isEmpty ? nil : description,
            category: selectedCategory,
            title: title,
            taskDescription: taskDescription.isEmpty ? nil : taskDescription,
            priority: selectedPriority,
            estimatedHours: Double(estimatedHours) ?? nil
        )
        
        // Serialize subtasks
        if !subtaskTemplates.isEmpty {
            template.subtasks = try? JSONEncoder().encodeToString(subtaskTemplates)
        }
        
        modelContext.insert(template)
        
        do {
            try modelContext.save()
            onTemplateCreated()
            dismiss()
        } catch {
            print("Error creating template: \(error)")
        }
    }
}

// MARK: - Task Templates View Model
@MainActor
class TaskTemplatesViewModel: ObservableObject {
    @Published var templates: [TaskTemplate] = []
    @Published var selectedCategory: String = "All"
    @Published var isLoading = false
    
    private let dataService: DataService
    
    init(dataService: DataService) {
        self.dataService = dataService
    }
    
    func loadTemplates(projectId: String? = nil) {
        isLoading = true
        
        do {
            var predicate: Predicate<TaskTemplate>?
            
            if selectedCategory != "All" {
                predicate = #Predicate<TaskTemplate> { $0.category == selectedCategory }
            }
            
            if let projectId = projectId {
                predicate = #Predicate<TaskTemplate> { $0.project?.id == projectId }
            }
            
            let sortDescriptor = [SortDescriptor<TaskTemplate>(\.createdAt, order: .reverse)]
            templates = try dataService.fetch(TaskTemplate.self, filter: sortDescriptor, predicate: predicate)
            
            isLoading = false
        } catch {
            print("Error loading templates: \(error)")
            isLoading = false
        }
    }
    
    func deleteTemplate(_ template: TaskTemplate) {
        dataService.delete(template)
        try? dataService.save()
        loadTemplates()
    }
    
    func applyTemplate(_ template: TaskTemplate, to task: Task) {
        task.title = template.title
        task.taskDescription = template.templateDescription
        task.priority = template.priority
        task.estimatedHours = template.estimatedHours
        task.template = template
        
        // Create subtasks
        if let subtaskTemplates = template.parsedSubtasks {
            for subtaskTemplate in subtaskTemplates {
                let subtask = Subtask(
                    title: subtaskTemplate.title,
                    order: subtaskTemplate.order
                )
                subtask.task = task
                task.subtasks?.append(subtask)
            }
        }
    }
}

// MARK: - Preview
#Preview("Task Templates") {
    TaskTemplatesView(projectId: nil, dataService: DataService())
}

