import CoreSpotlight
import SwiftData
import SwiftUI
import ProjectsDesignSystem

/// The app's window content: adaptive tab bar / sidebar, global sheets, errors and toasts.
struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if let issue = dependencies.storeIssue {
                StoreRecoveryView(issue: issue)
            } else {
                content
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .tint(TFColor.accent)
    }

    private var content: some View {
        @Bindable var router = dependencies.router
        @Bindable var errors = dependencies.errors

        return TabView(selection: $router.section) {
            Tab("Today", systemImage: "sun.max", value: AppRouter.Section.today) {
                NavigationStack(path: $router.todayPath) {
                    DashboardView()
                        .routeDestinations()
                }
            }
            Tab("Tasks", systemImage: "checklist", value: AppRouter.Section.tasks) {
                NavigationStack(path: $router.tasksPath) {
                    AllTasksView()
                        .routeDestinations()
                }
            }
            Tab("Projects", systemImage: "folder", value: AppRouter.Section.projects) {
                NavigationStack(path: $router.projectsPath) {
                    WorkspaceListView()
                        .routeDestinations()
                }
            }
            Tab("Templates", systemImage: "square.on.square", value: AppRouter.Section.templates) {
                NavigationStack(path: $router.templatesPath) {
                    TemplatesView()
                        .routeDestinations()
                }
            }
            #if os(iOS)
            Tab("Settings", systemImage: "gearshape", value: AppRouter.Section.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
            #endif
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(item: $router.sheet) { sheet in
            AppSheetView(sheet: sheet)
        }
        .alert(item: $errors.current) { error in
            Alert(title: Text(error.title), message: Text(error.message))
        }
        .overlay(alignment: .bottom) {
            ToastHost()
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .interactiveDismissDisabled()
        }
        .onOpenURL { url in
            dependencies.router.handle(url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
               let url = URL(string: identifier) {
                dependencies.router.handle(url)
            }
        }
        .task {
            await dependencies.onLaunch()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await dependencies.refreshPlatformState() }
            }
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding && !LaunchOptions.usesInMemoryStore },
            set: { isPresented in
                if !isPresented { hasCompletedOnboarding = true }
            }
        )
    }
}

/// Resolves the global sheets of ``AppRouter``.
private struct AppSheetView: View {
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .newTask(let projectID):
            TaskEditorView(mode: .create(projectID: projectID))
        case .editTask(let id):
            TaskEditorView(mode: .edit(id))
        case .newWorkspace:
            WorkspaceEditorView(workspaceID: nil)
        case .editWorkspace(let id):
            WorkspaceEditorView(workspaceID: id)
        case .newProject(let workspaceID):
            ProjectEditorView(mode: .create(workspaceID: workspaceID))
        case .editProject(let id):
            ProjectEditorView(mode: .edit(id))
        case .newTemplate(let workspaceID):
            TemplateEditorView(mode: .create(workspaceID: workspaceID))
        case .editTemplate(let id):
            TemplateEditorView(mode: .edit(id))
        }
    }
}

/// Shows the current toast above the tab bar.
private struct ToastHost: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        if let toast = dependencies.toasts.current {
            HStack(spacing: TFSpacing.medium) {
                Text(toast.message)
                    .font(.subheadline)
                if let actionTitle = toast.actionTitle {
                    Button(actionTitle) {
                        dependencies.toasts.runAction()
                    }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("toast.action")
                }
            }
            .padding(.horizontal, TFSpacing.large)
            .padding(.vertical, TFSpacing.medium)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, 72)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
        }
    }
}

extension View {
    /// Registers the destinations of every ``Route``.
    func routeDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .workspace(let id):
                WorkspaceDetailView(workspaceID: id)
            case .project(let id):
                ProjectDetailView(projectID: id)
            case .task(let id):
                TaskDetailView(taskID: id)
            case .labels(let workspaceID):
                LabelManagerView(workspaceID: workspaceID)
            case .customFields(let projectID):
                CustomFieldsManagerView(projectID: projectID)
            }
        }
    }
}
