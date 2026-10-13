import Foundation
import Observation
import SwiftUI
import ProjectsCore

/// Navigation destinations inside a section's `NavigationStack`. Values are identifiers, so
/// routes survive deletions (the destination shows "not found") and can come from deep links.
enum Route: Hashable {
    case workspace(UUID)
    case project(UUID)
    case task(UUID)
    case labels(workspaceID: UUID)
    case customFields(projectID: UUID)
}

/// Modal flows that can be started from anywhere (menus, keyboard shortcuts, deep links).
enum AppSheet: Identifiable, Hashable {
    case newTask(projectID: UUID?)
    case editTask(UUID)
    case newWorkspace
    case editWorkspace(UUID)
    case newProject(workspaceID: UUID?)
    case editProject(UUID)
    case newTemplate(workspaceID: UUID?)
    case editTemplate(UUID)

    var id: Self { self }
}

/// The single source of truth for navigation.
@Observable
final class AppRouter {
    enum Section: String, Hashable, CaseIterable {
        case today
        case tasks
        case projects
        case templates
        case settings
    }

    var section: Section = .today
    var todayPath: [Route] = []
    var tasksPath: [Route] = []
    var projectsPath: [Route] = []
    var templatesPath: [Route] = []
    var sheet: AppSheet?
    /// Incremented to ask the task list to focus its search field (⌘F).
    private(set) var searchFocusRequest = 0

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    func show(_ section: Section) {
        self.section = section
    }

    /// Pushes a route onto the stack of the visible section.
    func push(_ route: Route) {
        switch section {
        case .today, .settings:
            section = section == .settings ? .today : section
            todayPath.append(route)
        case .tasks:
            tasksPath.append(route)
        case .projects:
            projectsPath.append(route)
        case .templates:
            templatesPath.append(route)
        }
    }

    func requestSearchFocus() {
        section = .tasks
        searchFocusRequest += 1
    }

    /// Handles `projects://` URLs. Returns `false` for URLs the app does not understand.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let link = DeepLink(url: url) else { return false }
        handle(link)
        return true
    }

    func handle(_ link: DeepLink) {
        sheet = nil
        switch link {
        case .task(let id):
            push(.task(id))
        case .project(let id):
            section = .projects
            projectsPath = [.project(id)]
        case .workspace(let id):
            section = .projects
            projectsPath = [.workspace(id)]
        case .newTask:
            sheet = .newTask(projectID: nil)
        case .today:
            section = .today
            todayPath = []
        }
    }
}
