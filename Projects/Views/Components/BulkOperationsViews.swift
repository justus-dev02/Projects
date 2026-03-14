//
//  BulkOperationsViews.swift
//  Projects
//
//  TaskFlow - Bulk Operations UI Components
//

import SwiftUI

// MARK: - Bulk Actions Menu
struct BulkActionsMenu: View {
    @ObservedObject var selectionState: BulkSelectionState
    let tasks: [Task]
    let bulkOperationsService: BulkOperationsService
    let onActionCompleted: () -> Void
    
    @State private var showingStatusPicker = false
    @State private var showingPriorityPicker = false
    @State private var showingAssigneePicker = false
    @State private var showingDatePicker = false
    @State private var showingLabelPicker = false
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Status
            Menu {
                ForEach(Task.Status.allCases) { status in
                    Button {
                        applyStatus(status)
                    } label: {
                        // FIXED: Added SwiftUI. to avoid collision with custom Label model
                        SwiftUI.Label(status.rawValue, systemImage: status.icon)
                    }
                }
            } label: {
                MenuButton(icon: "checkmark.circle", label: "Status")
            }
            
            // Priority
            Menu {
                ForEach(Task.Priority.allCases) { priority in
                    Button {
                        applyPriority(priority)
                    } label: {
                        // FIXED: Added SwiftUI. to avoid collision with custom Label model
                        SwiftUI.Label(priority.rawValue, systemImage: priority.icon)
                    }
                }
            } label: {
                MenuButton(icon: "flag.fill", label: "Priority")
            }
            
            // Due Date
            Button(action: {
                showingDatePicker = true
            }) {
                MenuButton(icon: "calendar", label: "Due Date")
            }
            
            // Delete
            Button(role: .destructive) {
                deleteSelected()
            } label: {
                MenuButton(icon: "trash", label: "Delete")
            }
        }
        .padding()
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
    }
    
    private func applyStatus(_ status: Task.Status) {
        let selectedTasks = tasks.filter { selectionState.selectedTaskIds.contains($0.id) }
        
        do {
            _ = try bulkOperationsService.bulkUpdateStatus(tasks: selectedTasks, status: status.rawValue.lowercased())
            onActionCompleted()
        } catch {
            print("Error updating status: \(error)")
        }
    }
    
    private func applyPriority(_ priority: Task.Priority) {
        let selectedTasks = tasks.filter { selectionState.selectedTaskIds.contains($0.id) }
        
        do {
            _ = try bulkOperationsService.bulkUpdatePriority(tasks: selectedTasks, priority: priority.rawValue.lowercased())
            onActionCompleted()
        } catch {
            print("Error updating priority: \(error)")
        }
    }
    
    private func deleteSelected() {
        let selectedTasks = tasks.filter { selectionState.selectedTaskIds.contains($0.id) }
        
        do {
            _ = try bulkOperationsService.bulkDelete(tasks: selectedTasks)
            onActionCompleted()
        } catch {
            print("Error deleting tasks: \(error)")
        }
    }
}

// MARK: - Menu Button
struct MenuButton: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
            
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundColor(TaskFlowColors.textPrimary)
    }
}

// MARK: - Preview
#Preview("Bulk Operations") {
    Text("Bulk Operations Service")
}
