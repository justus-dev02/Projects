import Foundation
import Testing
import ProjectsCore
@testable import Projects

@Suite("AppRouter")
struct AppRouterTests {
    @Test func taskLinksPushOntoTheVisibleSection() {
        let router = AppRouter()
        let id = UUID()
        router.show(.tasks)

        #expect(router.handle(DeepLink.task(id).url))

        #expect(router.section == .tasks)
        #expect(router.tasksPath == [.task(id)])
    }

    @Test func projectLinksReplaceTheProjectsStack() {
        let router = AppRouter()
        router.projectsPath = [.workspace(UUID())]
        let id = UUID()

        router.handle(.project(id))

        #expect(router.section == .projects)
        #expect(router.projectsPath == [.project(id)])
    }

    @Test func newTaskLinkPresentsTheEditor() {
        let router = AppRouter()
        router.handle(.newTask)
        #expect(router.sheet == .newTask(projectID: nil))
    }

    @Test func linksDismissOpenSheets() {
        let router = AppRouter()
        router.present(.newWorkspace)
        router.handle(.today)
        #expect(router.sheet == nil)
        #expect(router.section == .today)
    }

    @Test func foreignURLsAreIgnored() throws {
        let router = AppRouter()
        #expect(!router.handle(try #require(URL(string: "https://example.com/task/1"))))
        #expect(router.todayPath.isEmpty)
    }

    @Test func taskLinksFromSettingsOpenInToday() {
        let router = AppRouter()
        router.show(.settings)
        let id = UUID()
        router.handle(.task(id))
        #expect(router.section == .today)
        #expect(router.todayPath == [.task(id)])
    }

    @Test func searchFocusSwitchesToTasks() {
        let router = AppRouter()
        let before = router.searchFocusRequest
        router.requestSearchFocus()
        #expect(router.section == .tasks)
        #expect(router.searchFocusRequest == before + 1)
    }
}
