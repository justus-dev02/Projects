//
//  CalendarView.swift
//  Projects
//
//  TaskFlow - Calendar View for Tasks
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Calendar View Model
@MainActor
class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var viewMode: CalendarViewMode = .month
    @Published var tasks: [Task] = []
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
    
    func loadTasks(for date: Date, projectId: String? = nil) {
        isLoading = true
        
        do {
            var allTasks: [Task] = []
            
            if let projectId = projectId {
                allTasks = try taskRepo.getTasksForProject(projectId: projectId)
            } else {
                // Get all tasks with due dates
                let predicate = #Predicate<Task> { $0.dueDate != nil }
                allTasks = try dataService.fetch(Task.self, filter: [], predicate: predicate)
            }
            
            tasks = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDate(dueDate, equalTo: date, toGranularity: .month)
            }
            
            isLoading = false
        } catch {
            print("Error loading tasks: \(error)")
            isLoading = false
        }
    }
    
    func tasksForDate(_ date: Date) -> [Task] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date)
        }.sorted { $0.dueDate ?? .distantFuture < $1.dueDate ?? .distantFuture }
    }
    
    func tasksForWeek(startingFrom startDate: Date) -> [Task] {
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: startDate) ?? Date()
        
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startDate && dueDate <= endDate
        }.sorted { $0.dueDate ?? .distantFuture < $1.dueDate ?? .distantFuture }
    }
    
    var calendarDays: [CalendarDay] {
        generateCalendarDays(for: selectedDate)
    }
    
    private func generateCalendarDays(for date: Date) -> [CalendarDay] {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)!
        let firstDayOfMonth = monthInterval.start
        
        // Get the first weekday of the month
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let offsetDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        // Start from the Sunday (or first weekday) before the first day
        let startDate = calendar.date(byAdding: .day, value: -offsetDays, to: firstDayOfMonth)!
        
        var days: [CalendarDay] = []
        
        for i in 0..<42 {
            guard let dayDate = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            
            let isCurrentMonth = calendar.isDate(dayDate, equalTo: date, toGranularity: .month)
            let isToday = calendar.isDateInToday(dayDate)
            let taskCount = tasksForDate(dayDate).count
            
            days.append(CalendarDay(
                date: dayDate,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                taskCount: taskCount
            ))
        }
        
        return days
    }
    
    func navigate(direction: NavigationDirection) {
        var components = DateComponents()
        
        switch viewMode {
        case .month:
            components.month = direction == .next ? 1 : -1
        case .week:
            components.weekOfYear = direction == .next ? 1 : -1
        }
        
        selectedDate = Calendar.current.date(byAdding: components, to: selectedDate) ?? Date()
        loadTasks(for: selectedDate)
    }
    
    enum NavigationDirection {
        case previous
        case next
    }
}

// MARK: - Calendar Day
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let taskCount: Int
    
    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
    
    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Calendar View Mode
enum CalendarViewMode: String, CaseIterable, Identifiable {
    case month = "Month"
    case week = "Week"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .month: return "calendar"
        case .week: return "calendar.badge.week"
        }
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedTask: Task?
    @State private var showingTaskDetail = false
    
    private let projectId: String?
    
    init(projectId: String? = nil, dataService: DataService) {
        self.projectId = projectId
        _viewModel = StateObject(wrappedValue: CalendarViewModel(dataService: dataService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            calendarToolbar
            
            Divider()
            
            // Calendar Content
            calendarContent
        }
        .background(TaskFlowColors.background)
        .task {
            viewModel.loadTasks(for: viewModel.selectedDate, projectId: projectId)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
    
    // MARK: - Calendar Toolbar
    private var calendarToolbar: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Navigation buttons
            Button(action: {
                viewModel.navigate(direction: .previous)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)
            }
            
            // Current period
            Text(formattedPeriod)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
                .frame(maxWidth: .infinity)
            
            Button(action: {
                viewModel.navigate(direction: .next)
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)
            }
            
            Divider()
                .frame(height: 24)
            
            // Today button
            Button("Today") {
                viewModel.selectedDate = Date()
                viewModel.loadTasks(for: Date(), projectId: projectId)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(TaskFlowColors.primary)
            
            // View mode picker
            Picker("View", selection: $viewModel.viewMode) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding()
        .background(TaskFlowColors.surface)
    }
    
    // MARK: - Calendar Content
    @ViewBuilder
    private var calendarContent: some View {
        switch viewModel.viewMode {
        case .month:
            monthView
        case .week:
            weekView
        }
    }
    
    // MARK: - Month View
    private var monthView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Weekday headers
                weekdayHeaders
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                    ForEach(viewModel.calendarDays) { day in
                        CalendarDayCell(
                            day: day,
                            tasks: viewModel.tasksForDate(day.date),
                            onTap: { task in
                                selectedTask = task
                                showingTaskDetail = true
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Week View
    private var weekView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Week days header
                HStack(spacing: 1) {
                    // FIXED: Changed to an if let to avoid ViewBuilder return type confusion
                    ForEach(0..<7, id: \.self) { index in
                        if let date = Calendar.current.date(byAdding: .day, value: index, to: weekStartDate) {
                            WeekDayHeaderCell(date: date, isToday: Calendar.current.isDateInToday(date))
                        }
                    }
                }
                .frame(height: 60)
                
                // Time slots
                TimeGridView(tasks: viewModel.tasksForWeek(startingFrom: weekStartDate)) { task in
                    selectedTask = task
                    showingTaskDetail = true
                }
            }
        }
    }
    
    private var weekdayHeaders: some View {
        HStack(spacing: 1) {
            ForEach(shortWeekdayNames, id: \.self) { dayName in
                Text(dayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, TaskFlowSpacing.medium)
                    .background(TaskFlowColors.background)
            }
        }
    }
    
    private var shortWeekdayNames: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale.current
        
        var days: [String] = []
        let firstWeekday = Calendar.current.firstWeekday
        
        for i in 0..<7 {
            let weekday = (firstWeekday + i - 1) % 7 + 1
            if let date = Calendar.current.date(from: DateComponents(weekday: weekday)) {
                days.append(formatter.string(from: date))
            }
        }
        
        return days
    }
    
    private var weekStartDate: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: viewModel.selectedDate)
        let diff = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -diff, to: viewModel.selectedDate) ?? Date()
    }
    
    private var formattedPeriod: String {
        let formatter = DateFormatter()
        
        switch viewModel.viewMode {
        case .month:
            formatter.dateFormat = "MMMM yyyy"
        case .week:
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: viewModel.selectedDate)
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let day: CalendarDay
    let tasks: [Task]
    let onTap: (Task) -> Void
    
    @State private var showingTasks = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Day number
            HStack {
                Text("\(day.dayNumber)")
                    .font(.system(size: 12, weight: day.isToday ? .bold : .regular))
                    .foregroundColor(dayColor)
                    .frame(width: 24, height: 24)
                    .background(day.isToday ? TaskFlowColors.primary.opacity(0.1) : Color.clear)
                    .cornerRadius(TaskFlowRadius.small)
                
                Spacer()
                
                // Task count indicator
                if day.taskCount > 0 {
                    Circle()
                        .fill(taskCountColor)
                        .frame(width: 6, height: 6)
                }
            }
            
            // Task dots
            if !tasks.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(tasks.prefix(4), id: \.id) { task in
                            TaskDotView(task: task)
                                .onTapGesture {
                                    onTap(task)
                                }
                        }
                        
                        if tasks.count > 4 {
                            Text("+\(tasks.count - 4)")
                                .font(.system(size: 9))
                                .foregroundColor(TaskFlowColors.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(4)
        .frame(minHeight: 80)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(TaskFlowColors.border, lineWidth: day.isCurrentMonth ? 0.5 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !tasks.isEmpty {
                showingTasks = true
            }
        }
        .popover(isPresented: $showingTasks) {
            DayTasksPopover(tasks: tasks, onTap: onTap)
                .frame(width: 250, height: min(400, CGFloat(tasks.count) * 80 + 40))
        }
    }
    
    private var backgroundColor: Color {
        if !day.isCurrentMonth {
            return TaskFlowColors.background.opacity(0.5)
        }
        if day.isToday {
            return TaskFlowColors.primary.opacity(0.02)
        }
        return TaskFlowColors.surface
    }
    
    private var dayColor: Color {
        if day.isToday {
            return TaskFlowColors.primary
        } else if day.isCurrentMonth {
            return TaskFlowColors.textPrimary
        } else {
            return TaskFlowColors.textTertiary
        }
    }
    
    private var taskCountColor: Color {
        if tasks.contains(where: { $0.isOverdue }) {
            return TaskFlowColors.error
        } else if tasks.contains(where: { $0.isDueToday }) {
            return TaskFlowColors.warning
        } else {
            return TaskFlowColors.success
        }
    }
}

// MARK: - Task Dot View
struct TaskDotView: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(task.title)
                .font(.system(size: 9))
                .foregroundColor(TaskFlowColors.textPrimary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
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

// MARK: - Day Tasks Popover
struct DayTasksPopover: View {
    let tasks: [Task]
    let onTap: (Task) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.small) {
            Text("Tasks for this day")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(TaskFlowColors.textPrimary)
                .padding(.horizontal)
                .padding(.top)
            
            Divider()
            
            ForEach(tasks, id: \.id) { task in
                Button(action: {
                    onTap(task)
                }) {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(TaskFlowColors.textPrimary)
                                .lineLimit(1)
                            
                            TFPriorityBadge(priority: task.priority, size: .small, style: .outline)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(TaskFlowColors.background)
                    .cornerRadius(TaskFlowRadius.small)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var statusColor: Color {
        switch Task.Priority(rawValue: tasks.first?.priority ?? "medium") {
        case .low: return TaskFlowColors.priorityLow
        case .medium: return TaskFlowColors.priorityMedium
        case .high: return TaskFlowColors.priorityHigh
        case .urgent: return TaskFlowColors.priorityUrgent
        case .none: return TaskFlowColors.priorityMedium
        }
    }
}

// MARK: - Week Day Header Cell
struct WeekDayHeaderCell: View {
    let date: Date
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(shortWeekdayName)
                .font(.system(size: 11))
                .foregroundColor(TaskFlowColors.textSecondary)
            
            Text("\(dayNumber)")
                .font(.system(size: 18, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? TaskFlowColors.primary : TaskFlowColors.textPrimary)
                .frame(width: 32, height: 32)
                .background(isToday ? TaskFlowColors.primary.opacity(0.1) : Color.clear)
                .cornerRadius(TaskFlowRadius.full)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var shortWeekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
}

// MARK: - Time Grid View
struct TimeGridView: View {
    let tasks: [Task]
    let onTaskTap: (Task) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24) { hour in
                TimeSlotRow(hour: hour, tasks: tasks.filter { taskHour($0) == hour }, onTaskTap: onTaskTap)
                    .frame(height: 60)
            }
        }
    }
    
    private func taskHour(_ task: Task) -> Int {
        guard let dueDate = task.dueDate else { return 0 }
        return Calendar.current.component(.hour, from: dueDate)
    }
}

// MARK: - Time Slot Row
struct TimeSlotRow: View {
    let hour: Int
    let tasks: [Task]
    let onTaskTap: (Task) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Time label
            Text(formattedHour)
                .font(.system(size: 11))
                .foregroundColor(TaskFlowColors.textTertiary)
                .frame(width: 50)
                .padding(.top, 8)
            
            // Tasks in this hour
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tasks, id: \.id) { task in
                        TaskChipView(task: task)
                            .onTapGesture {
                                onTaskTap(task)
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(TaskFlowColors.border),
            alignment: .top
        )
    }
    
    private var formattedHour: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Task Chip View
struct TaskChipView: View {
    let task: Task
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(task.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(TaskFlowColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(TaskFlowRadius.small)
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
#Preview("Calendar View") {
    CalendarView(projectId: nil, dataService: DataService())
}
