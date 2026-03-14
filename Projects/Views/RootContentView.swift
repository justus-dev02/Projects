//
//  RootContentView.swift
//  Projects
//
//  TaskFlow - Main Root Content View with Sidebar Navigation
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Root Content View
struct RootContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                LoadingView()
            case .unauthenticated:
                OnboardingView(onComplete: {
                    authViewModel.loginLocally()
                })
            case .authenticated:
                mainAppView
            }
        }
    }

    // MARK: - Main App View
    private var mainAppView: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad/Mac - Sidebar layout
                NavigationSplitView {
                    SidebarView()
                } detail: {
                    DashboardView()
                }
            } else {
                // iPhone - Tab layout
                MainTabView()
            }
        }
    }
}

// MARK: - Auth View Model
@MainActor
class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unknown

    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService.shared

        // Observe auth state changes
        self.authService.authStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.authState = state
            }
            .store(in: &cancellables)
    }

    func loginLocally() {
        _ = try? authService.loginLocally()
    }

    func logout() {
        _ = try? authService.logout()
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: TaskFlowSpacing.large) {
            // App Logo
            ZStack {
                Circle()
                    .fill(TaskFlowColors.primary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(TaskFlowColors.primary)
            }
            
            // Loading Indicator
            ProgressView()
                .scaleEffect(1.2)
            
            Text("TaskFlow")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(TaskFlowColors.textPrimary)
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @State private var currentPage = 0
    let onComplete: () -> Void
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "briefcase.fill",
            title: "Welcome to TaskFlow",
            description: "Your personal task management solution. Organize projects, track progress, and get things done.",
            color: TaskFlowColors.primary
        ),
        OnboardingPage(
            icon: "square.grid.2x2.fill",
            title: "Kanban Boards",
            description: "Visualize your workflow with intuitive Kanban boards. Drag and drop tasks between columns.",
            color: TaskFlowColors.success
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Collaborate",
            description: "Work together with your team. Assign tasks, add comments, and track progress together.",
            color: TaskFlowColors.statusInProgress
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "Get Started",
            description: "You're all set! Start managing your tasks efficiently with TaskFlow.",
            color: TaskFlowColors.warning
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Page Indicator
            HStack(spacing: TaskFlowSpacing.small) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? TaskFlowColors.primary : TaskFlowColors.border)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
            }
            .padding(.bottom, TaskFlowSpacing.xLarge)
            
            // Continue Button
            TFButton(
                title: currentPage == pages.count - 1 ? "Get Started" : "Continue",
                style: .primary,
                size: .large
            ) {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring) {
                        currentPage += 1
                    }
                } else {
                    onComplete()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, TaskFlowSpacing.xHuge)
        }
        .background(TaskFlowColors.background)
    }
}

// MARK: - Onboarding Page
struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Onboarding Page View
struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: TaskFlowSpacing.xLarge) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.icon)
                    .font(.system(size: 50))
                    .foregroundColor(page.color)
            }
            
            // Text
            VStack(spacing: TaskFlowSpacing.medium) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 16))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TaskFlowSpacing.xHuge)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Sidebar View
struct SidebarView: View {
    @State private var selectedDestination: SidebarDestination = .dashboard
    @Environment(\.dismiss) private var dismiss

    enum SidebarDestination: Hashable {
        case dashboard
        case workspaces
        case myTasks
        case notifications
        case settings
    }

    var body: some View {
        NavigationStack {
            List {
                // Main Section
                Section {
                    NavigationLink(value: SidebarDestination.dashboard) {
                        SwiftUI.Label("Dashboard", systemImage: "speedometer")
                    }

                    NavigationLink(value: SidebarDestination.workspaces) {
                        SwiftUI.Label("Workspaces", systemImage: "briefcase.fill")
                    }

                    NavigationLink(value: SidebarDestination.myTasks) {
                        SwiftUI.Label("My Tasks", systemImage: "checkmark.seal.fill")
                    }
                } header: {
                    Text("Main")
                }

                // Notifications
                Section {
                    NavigationLink(value: SidebarDestination.notifications) {
                        HStack {
                            SwiftUI.Label("Notifications", systemImage: "bell.fill")
                            Spacer()
                            NotificationBadge(count: 3)
                        }
                    }
                }

                // Settings
                Section {
                    NavigationLink(value: SidebarDestination.settings) {
                        SwiftUI.Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("TaskFlow")
            .navigationDestination(for: SidebarDestination.self) { destination in
                switch destination {
                case .dashboard:
                    DashboardView()
                case .workspaces:
                    WorkspaceListView()
                case .myTasks:
                    MyTasksView()
                case .notifications:
                    NotificationsView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                SwiftUI.Label("Home", systemImage: "speedometer")
            }
            .tag(0)

            NavigationStack {
                WorkspaceListView()
            }
            .tabItem {
                SwiftUI.Label("Workspaces", systemImage: "briefcase.fill")
            }
            .tag(1)

            NavigationStack {
                MyTasksView()
            }
            .tabItem {
                SwiftUI.Label("Tasks", systemImage: "checkmark.seal.fill")
            }
            .tag(2)

            NavigationStack {
                NotificationsView()
            }
            .tabItem {
                SwiftUI.Label("Notifications", systemImage: "bell.fill")
            }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                SwiftUI.Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(4)
        }
    }
}

// MARK: - My Tasks View
struct MyTasksView: View {
    @Query private var tasks: [Task]
    @State private var selectedTask: Task?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xLarge) {
                // Header
                VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                    Text("My Tasks")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    Text("Tasks assigned to you")
                        .font(.system(size: 14))
                        .foregroundColor(TaskFlowColors.textSecondary)
                }
                
                // Task Lists by Status
                TaskStatusSection(
                    title: "Due Today",
                    icon: "sun.max.fill",
                    color: TaskFlowColors.warning,
                    tasks: tasks.filter { $0.isDueToday }
                )
                
                TaskStatusSection(
                    title: "Overdue",
                    icon: "exclamationmark.triangle.fill",
                    color: TaskFlowColors.error,
                    tasks: tasks.filter { $0.isOverdue }
                )
                
                TaskStatusSection(
                    title: "In Progress",
                    icon: "arrow.triangle.2.circlepath",
                    color: TaskFlowColors.statusInProgress,
                    tasks: tasks.filter { $0.status == "inProgress" }
                )
            }
            .padding()
        }
        .background(TaskFlowColors.background)
        .navigationTitle("My Tasks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
    }
}

// MARK: - Task Status Section
struct TaskStatusSection: View {
    let title: String
    let icon: String
    let color: Color
    let tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(TaskFlowColors.textPrimary)
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
            
            if tasks.isEmpty {
                Text("No tasks in this section")
                    .font(.system(size: 14))
                    .foregroundColor(TaskFlowColors.textTertiary)
                    .padding(.vertical, TaskFlowSpacing.large)
            } else {
                VStack(spacing: TaskFlowSpacing.small) {
                    ForEach(tasks.prefix(5), id: \.id) { task in
                        TaskListRow(task: task)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Root Content") {
    RootContentView()
}

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
}

#Preview("Sidebar") {
    SidebarView()
}

#Preview("My Tasks") {
    MyTasksView()
}
