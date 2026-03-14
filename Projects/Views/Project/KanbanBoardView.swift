//
//  KanbanBoardView.swift
//  Projects
//
//  TaskFlow - Kanban Board with Drag & Drop
//

import SwiftUI
import SwiftData

// MARK: - Kanban Board View with Drag & Drop
struct KanbanBoardView: View {
    @ObservedObject var viewModel: ProjectDetailViewModel
    @Environment(\.modelContext) private var modelContext
    
    private let dragDropService: DragDropService
    
    init(viewModel: ProjectDetailViewModel) {
        self.viewModel = viewModel
        self.dragDropService = DragDropService(dataService: DataService(modelContext: viewModel.modelContext))
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: TaskFlowSpacing.large) {
                ForEach(viewModel.columns, id: \.id) { column in
                    KanbanColumnView(
                        column: column,
                        tasks: viewModel.tasksForColumn(column),
                        viewModel: viewModel,
                        dragDropService: dragDropService
                    )
                }
            }
            .padding()
        }
        .background(TaskFlowColors.background)
    }
}

// MARK: - Kanban Column View
struct KanbanColumnView: View {
    let column: BoardColumn
    let tasks: [Task]
    @ObservedObject var viewModel: ProjectDetailViewModel
    let dragDropService: DragDropService
    
    @State private var isExpanded = true
    @State private var showingAddTask = false
    @State private var selectedTask: Task?
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            // Column Header
            columnHeader
            
            // Tasks with Drop Zone
            if isExpanded {
                tasksDropZone
            }
        }
        .frame(width: 320)
        .frame(minHeight: 400)
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.large)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
        .dropDestination(for: DragDropTask.self) { droppedTasks, location in
            handleDrop(droppedTasks: droppedTasks, location: location)
            return true
        }
    }
    
    // MARK: - Column Header
    private var columnHeader: some View {
        HStack {
            Circle()
                .fill(Color(hex: column.color))
                .frame(width: 10, height: 10)
            
            Text(column.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
            
            Spacer()
            
            Text("\(tasks.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(TaskFlowColors.textTertiary)
                .padding(.horizontal, TaskFlowSpacing.small)
                .padding(.vertical, 2)
                .background(TaskFlowColors.background)
                .cornerRadius(TaskFlowRadius.small)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
        }
        .padding(.horizontal, TaskFlowSpacing.medium)
        .padding(.vertical, TaskFlowSpacing.small)
    }
    
    // MARK: - Tasks Drop Zone
    private var tasksDropZone: some View {
        LazyVStack(spacing: TaskFlowSpacing.small) {
            ForEach(tasks, id: \.id) { task in
                DraggableTaskCard(
                    task: task,
                    viewModel: viewModel,
                    dragDropService: dragDropService
                )
                .onTapGesture {
                    viewModel.selectedTask = task
                }
            }
            
            // Add Task Button
            Button(action: {
                showingAddTask = true
            }) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("Add Task")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(TaskFlowColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TaskFlowSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                        .stroke(TaskFlowColors.border, lineWidth: 1)
                        .background(TaskFlowColors.background)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingAddTask) {
            CreateTaskView(viewModel: viewModel)
        }
    }
    
    // MARK: - Handle Drop
    private func handleDrop(droppedTasks: [DragDropTask], location: CGPoint) {
        for droppedTask in droppedTasks {
            // Find the task in the viewModel's tasks array
            guard let task = viewModel.tasks.first(where: { $0.id == droppedTask.taskId }) else { continue }

            // Find the task at the drop location
            let dropIndex = Int(location.y / 80) // Approximate card height

            do {
                try dragDropService.moveTask(task, to: column, at: Swift.max(0, dropIndex))
                viewModel.loadData()
            } catch {
                print("Error moving task: \(error)")
            }
        }
    }
}

// MARK: - Draggable Task Card
struct DraggableTaskCard: View {
    let task: Task
    @ObservedObject var viewModel: ProjectDetailViewModel
    let dragDropService: DragDropService
    
    @State private var dragState: DragState = .inactive
    @State private var showingEditSheet = false
    
    var body: some View {
        TaskCardView(task: task)
            .gesture(dragGesture)
            .opacity(dragState.isActive ? 0.5 : 1.0)
            .scaleEffect(dragState.isDragging ? 1.02 : 1.0)
            .shadow(color: dragState.isDragging ? .black.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
            .contextMenu {
                taskContextMenu
            }
    }
    
    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                withAnimation(.easeInOut(duration: 0.15)) {
                    dragState = .dragging(translation: value.translation)
                }
            }
            .onEnded { value in
                withAnimation(.easeInOut(duration: 0.15)) {
                    dragState = .inactive
                }
                
                // Handle drop based on horizontal movement
                let horizontalTranslation = value.translation.width
                
                if abs(horizontalTranslation) > 100 {
                    // Move to adjacent column
                    moveTaskToAdjacentColumn(direction: horizontalTranslation > 0 ? 1 : -1)
                }
            }
    }
    
    // MARK: - Context Menu
    @ViewBuilder
    private var taskContextMenu: some View {
        Button {
            showingEditSheet = true
        } label: {
            SwiftUI.Label("Edit", systemImage: "pencil")
        }
        
        Menu {
            ForEach(Task.Priority.allCases) { priority in
                Button {
                    // FIXED: Removed the invalid .perform block.
                    // Since this is triggered from a SwiftUI View, we are already on the MainActor
                    task.priority = priority.rawValue.lowercased()
                    task.updatedAt = Date()
                    try? viewModel.dataService.save()
                    viewModel.loadData()
                } label: {
                    SwiftUI.Label(priority.rawValue, systemImage: priority.icon)
                }
            }
        } label: {
            SwiftUI.Label("Priority", systemImage: "flag.fill")
        }
        
        Divider()
        
        Button(role: .destructive) {
            try? viewModel.deleteTask(task)
        } label: {
            SwiftUI.Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Move to Adjacent Column
    private func moveTaskToAdjacentColumn(direction: Int) {
        guard let currentColumn = task.column,
              let project = task.project else { return }
        
        let columns = (project.boardColumns ?? []).sorted { $0.order < $1.order }
        guard let currentIndex = columns.firstIndex(where: { $0.id == currentColumn.id }) else { return }
        
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < columns.count else { return }
        
        let targetColumn = columns[newIndex]
        
        do {
            try dragDropService.moveTask(task, to: targetColumn, at: task.order)
            viewModel.loadData()
        } catch {
            print("Error moving task: \(error)")
        }
    }
}

// MARK: - Task Card View
struct TaskCardView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            // Labels
            if let labels = task.labels, !labels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(labels.prefix(3), id: \.id) { taskLabel in
                            if let label = taskLabel.label {
                                TFLabelBadge(name: label.name, colorHex: label.color, size: .small)
                            }
                        }
                    }
                }
            }
            
            // Title
            Text(task.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(TaskFlowColors.textPrimary)
                .lineLimit(2)
            
            // Description preview
            if let taskDescription = task.taskDescription {
                Text(taskDescription)
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Footer
            footerContent
        }
        .padding(TaskFlowSpacing.medium)
        .background(TaskFlowColors.surface)
        .cornerRadius(TaskFlowRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                .stroke(TaskFlowColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Footer Content
    @ViewBuilder
    private var footerContent: some View {
        VStack(spacing: TaskFlowSpacing.small) {
            HStack {
                // Priority
                TFPriorityBadge(priority: task.priority, size: .small, style: .outline)
                
                Spacer()
                
                // Due Date
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(task.isOverdue ? TaskFlowColors.error : TaskFlowColors.textTertiary)
                }
            }
            
            // Meta info row
            HStack(spacing: TaskFlowSpacing.small) {
                // Comments count
                if task.commentCount > 0 {
                    SwiftUI.Label("\(task.commentCount)", systemImage: "message.fill")
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                // Attachments count
                if task.attachmentCount > 0 {
                    SwiftUI.Label("\(task.attachmentCount)", systemImage: "paperclip")
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
                
                Spacer()
                
                // Dependency indicator
                if task.isBlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(TaskFlowColors.warning)
                }
                
                // Assignee
                if let assignee = task.assignee {
                    TFAvatar(name: assignee.displayName, colorHex: assignee.avatarColor, size: .xSmall)
                }
            }
            
            // Subtask Progress
            if task.totalSubtaskCount > 0 {
                TFTaskProgress(
                    completed: task.completedSubtaskCount,
                    total: task.totalSubtaskCount,
                    height: 4
                )
            }
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview("Kanban Board") {
    NavigationStack {
        KanbanBoardView(viewModel: ProjectDetailViewModel(project: Project(name: "Test Project"), modelContext: try! ModelContext(ModelContainer()))
        )
    }
}
