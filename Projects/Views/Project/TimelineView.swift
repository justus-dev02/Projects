//
//  TimelineView.swift
//  Projects
//
//  TaskFlow - Timeline/Gantt View for Tasks
//

import SwiftUI
import SwiftData
import Combine // FIXED: Required for ObservableObject and @Published

// MARK: - Timeline View Model
@MainActor
class TimelineViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @Published var zoomLevel: TimelineZoomLevel = .week
    @Published var isLoading = false
    
    private let dataService: DataService
    private let taskRepo: TaskRepository
    
    init(
        dataService: DataService,
        taskRepo: TaskRepository? = nil
    ) {
        self.dataService = dataService
        self.taskRepo = taskRepo ?? TaskRepository(dataService: dataService)
    }
    
    func loadTasks(projectId: String? = nil) {
        isLoading = true
        
        do {
            var allTasks: [Task] = []
            
            if let projectId = projectId {
                allTasks = try taskRepo.getTasksForProject(projectId: projectId)
            } else {
                let predicate = #Predicate<Task> { $0.dueDate != nil }
                allTasks = try dataService.fetch(Task.self, filter: [], predicate: predicate)
            }
            
            // Filter tasks within date range
            tasks = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= startDate && dueDate <= endDate
            }.sorted { $0.dueDate ?? .distantFuture < $1.dueDate ?? .distantFuture }
            
            isLoading = false
        } catch {
            print("Error loading tasks: \(error)")
            isLoading = false
        }
    }
    
    func navigate(direction: NavigationDirection) {
        var components = DateComponents()
        
        switch zoomLevel {
        case .day:
            components.day = direction == .next ? 1 : -1
        case .week:
            components.weekOfYear = direction == .next ? 1 : -1
        case .month:
            components.month = direction == .next ? 1 : -1
        }
        
        startDate = Calendar.current.date(byAdding: components, to: startDate) ?? Date()
        endDate = Calendar.current.date(byAdding: components, to: endDate) ?? Date()
        loadTasks()
    }
    
    func setZoomLevel(_ level: TimelineZoomLevel) {
        zoomLevel = level
        adjustDateRange(for: level)
        loadTasks()
    }
    
    private func adjustDateRange(for zoomLevel: TimelineZoomLevel) {
        switch zoomLevel {
        case .day:
            endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? Date()
        case .week:
            endDate = Calendar.current.date(byAdding: .day, value: 27, to: startDate) ?? Date()
        case .month:
            endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? Date()
        }
    }
    
    // MARK: - Date Helpers
    var dateRange: [Date] {
        var dates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            dates.append(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? Date()
        }
        
        return dates
    }
    
    func dayPosition(for date: Date) -> CGFloat {
        let totalDays = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        let daysFromStart = Calendar.current.dateComponents([.day], from: startDate, to: date).day ?? 0
        return CGFloat(daysFromStart) / CGFloat(totalDays)
    }
    
    enum NavigationDirection {
        case previous
        case next
    }
}

// MARK: - Timeline Zoom Level
enum TimelineZoomLevel: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    
    var id: String { rawValue }
    
    var columnWidth: CGFloat {
        switch self {
        case .day: return 100
        case .week: return 40
        case .month: return 20
        }
    }
}

// MARK: - Timeline View
struct TimelineView: View {
    @StateObject private var viewModel: TimelineViewModel
    @State private var selectedTask: Task?
    
    private let projectId: String?
    
    init(projectId: String? = nil, dataService: DataService) {
        self.projectId = projectId
        _viewModel = StateObject(wrappedValue: TimelineViewModel(dataService: dataService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            timelineToolbar
            
            Divider()
            
            // Timeline Content
            timelineContent
        }
        .background(TaskFlowColors.background)
        .task {
            viewModel.loadTasks(projectId: projectId)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
    
    // MARK: - Timeline Toolbar
    private var timelineToolbar: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Navigation
            HStack(spacing: TaskFlowSpacing.small) {
                Button(action: {
                    viewModel.navigate(direction: .previous)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(TaskFlowColors.primary.opacity(0.1)))
                }
                
                Text(formattedDateRange)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .frame(minWidth: 180)
                
                Button(action: {
                    viewModel.navigate(direction: .next)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(TaskFlowColors.primary.opacity(0.1)))
                }
            }
            
            Spacer()
            
            // Today button
            Button("Today") {
                withAnimation {
                    viewModel.startDate = Date()
                    viewModel.setZoomLevel(viewModel.zoomLevel)
                }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(TaskFlowColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(TaskFlowColors.primary.opacity(0.1))
            .cornerRadius(8)
            
            // Zoom picker
            Picker("Zoom", selection: $viewModel.zoomLevel) {
                ForEach(TimelineZoomLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding()
        .background(TaskFlowColors.surface.opacity(0.8))
        .liquidGlass(style: .thin, cornerRadius: 0)
    }
    
    // MARK: - Timeline Content
    private var timelineContent: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    // Date Headers
                    dateHeadersView(width: geometry.size.width)
                        .padding(.vertical, 8)
                        .background(TaskFlowColors.background.opacity(0.5))
                    
                    Divider()
                    
                    // Task Bars
                    tasksListView(width: geometry.size.width)
                }
            }
        }
    }
    
    // MARK: - Date Headers
    private func dateHeadersView(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Sidebar
            Text("Tasks")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(TaskFlowColors.textSecondary)
                .frame(width: 200)
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(TaskFlowColors.border),
                    alignment: .trailing
                )
            
            // Date columns
            ForEach(viewModel.dateRange, id: \.self) { date in
                DateColumnView(date: date, zoomLevel: viewModel.zoomLevel)
                    .frame(width: viewModel.zoomLevel.columnWidth)
            }
        }
    }
    
    // MARK: - Tasks List
    private func tasksListView(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.tasks, id: \.id) { task in
                TaskTimelineRow(
                    task: task,
                    dateRange: viewModel.dateRange,
                    zoomLevel: viewModel.zoomLevel
                )
                .onTapGesture {
                    selectedTask = task
                }
                .frame(height: 44)
            }
        }
    }
    
    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = viewModel.zoomLevel == .month ? "MMMM yyyy" : "MMM d, yyyy"
        
        return "\(formatter.string(from: viewModel.startDate)) - \(formatter.string(from: viewModel.endDate))"
    }
}

// MARK: - Date Column View
struct DateColumnView: View {
    let date: Date
    let zoomLevel: TimelineZoomLevel
    
    var body: some View {
        VStack(spacing: 2) {
            Text(shortWeekdayName)
                .font(.system(size: 9))
                .foregroundColor(TaskFlowColors.textTertiary)
            
            Text("\(dayNumber)")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? TaskFlowColors.primary : TaskFlowColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .background(isToday ? TaskFlowColors.primary.opacity(0.05) : Color.clear)
    }
    
    private var shortWeekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Task Timeline Row
struct TaskTimelineRow: View {
    let task: Task
    let dateRange: [Date]
    let zoomLevel: TimelineZoomLevel
    
    var body: some View {
        HStack(spacing: 0) {
            // Task Name Sidebar
            Text(task.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(TaskFlowColors.textPrimary)
                .lineLimit(1)
                .frame(width: 200, alignment: .leading)
                .padding(.horizontal)
                .overlay(
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(TaskFlowColors.border),
                    alignment: .trailing
                )
            
            // Timeline Area
            ZStack(alignment: .leading) {
                // Grid lines
                ForEach(0..<dateRange.count, id: \.self) { index in
                    Rectangle()
                        .frame(width: 1)
                        .foregroundColor(TaskFlowColors.border.opacity(0.3))
                        .offset(x: CGFloat(index) * zoomLevel.columnWidth)
                }
                
                // Task Bar
                if let dueDate = task.dueDate {
                    TaskBarView(
                        task: task,
                        position: calculatePosition(for: dueDate),
                        width: zoomLevel.columnWidth
                    )
                }
            }
        }
    }
    
    private func calculatePosition(for date: Date) -> CGFloat {
        guard let firstDate = dateRange.first,
              let lastDate = dateRange.last else { return 0 }
        
        let totalSeconds = lastDate.timeIntervalSince(firstDate)
        let elapsedSeconds = date.timeIntervalSince(firstDate)
        
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(elapsedSeconds / totalSeconds)
    }
}

// MARK: - Task Bar View
struct TaskBarView: View {
    let task: Task
    let position: CGFloat
    let width: CGFloat
    
    var body: some View {
        HStack {
            if position > 0 {
                Spacer(minLength: 0)
                    .frame(width: position * 100)
            }
            
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                
                Text(task.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(statusColor, lineWidth: 1)
            )
            .frame(maxWidth: width * 2)
            
            Spacer(minLength: 0)
        }
    }
    
    private var statusColor: Color {
        switch task.status.lowercased() {
        case "todo": return TaskFlowColors.statusTodo
        case "inprogress": return TaskFlowColors.statusInProgress
        case "review": return TaskFlowColors.statusReview
        case "done": return TaskFlowColors.statusDone
        default: return TaskFlowColors.statusTodo
        }
    }
}

// MARK: - Preview
#Preview("Timeline View") {
    TimelineView(projectId: nil, dataService: DataService())
}
