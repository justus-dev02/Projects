import XCTest

// These flows use the iPhone tab bar and swipe gestures; the Mac has its own tests
// (MacProjectsUITests).
#if os(iOS)
/// End-to-end flows. The tests only use accessibility identifiers and text typed by the test
/// itself, so they pass in every language (the test plan runs them in English and German).
final class AppFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private enum Section: Int {
        case today, tasks, projects, templates, settings
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed-demo-data"]
        app.launch()
        return app
    }

    @MainActor
    private func open(_ section: Section, in app: XCUIApplication) {
        let button = app.tabBars.buttons.element(boundBy: section.rawValue)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    @MainActor
    private func createTask(titled title: String, in app: XCUIApplication) {
        open(.tasks, in: app)
        app.buttons["tasks.new"].firstMatch.tap()
        let titleField = app.textFields["taskEditor.title"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        app.buttons["editor.save"].firstMatch.tap()
        XCTAssertTrue(reveal(app.staticTexts[title], in: app), "New task should appear in the list")
    }

    /// Scrolls the task page until the element exists.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, attempts: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        for _ in 0..<attempts where !element.exists {
            app.swipeUp()
        }
        return element.waitForExistence(timeout: 2)
    }

    @MainActor
    private func row(containing title: String, in app: XCUIApplication) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier == 'task.row' AND label CONTAINS %@", title)
        let row = app.descendants(matching: .any).matching(predicate).firstMatch
        _ = reveal(row, in: app)
        return row
    }

    // MARK: Tests

    @MainActor
    func testCreatedTaskAppearsInTheTaskList() {
        let app = launch()
        createTask(titled: "Prepare UI test report", in: app)
    }

    @MainActor
    func testCompletingATaskRemovesItFromOpenTasks() {
        let app = launch()
        let title = "Complete me in a UI test"
        createTask(titled: title, in: app)

        row(containing: title, in: app).buttons["task.completion"].tap()

        let disappeared = NSPredicate(format: "exists == false")
        expectation(for: disappeared, evaluatedWith: app.staticTexts[title])
        waitForExpectations(timeout: 5)
    }

    @MainActor
    func testDeletedTaskCanBeRestoredFromTheToast() {
        let app = launch()
        let title = "Delete and undo"
        createTask(titled: title, in: app)

        row(containing: title, in: app).press(forDuration: 1.2)
        let delete = app.buttons["task.delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertFalse(app.staticTexts[title].waitForExistence(timeout: 1))

        let undo = app.buttons["toast.action"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()

        XCTAssertTrue(reveal(app.staticTexts[title], in: app))
    }

    @MainActor
    func testCreatingAWorkspaceAndProjectOpensTheBoard() {
        let app = launch()
        open(.projects, in: app)
        app.buttons["workspaces.new"].firstMatch.tap()
        let workspaceName = app.textFields["workspaceEditor.name"].firstMatch
        XCTAssertTrue(workspaceName.waitForExistence(timeout: 5))
        workspaceName.tap()
        workspaceName.typeText("UI Test Workspace")
        app.buttons["editor.save"].firstMatch.tap()

        let newProject = app.buttons["workspace.newProject"].firstMatch
        XCTAssertTrue(newProject.waitForExistence(timeout: 5))
        newProject.tap()
        let projectName = app.textFields["projectEditor.name"].firstMatch
        XCTAssertTrue(projectName.waitForExistence(timeout: 5))
        projectName.tap()
        projectName.typeText("UI Test Project")
        app.buttons["editor.save"].firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["board"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDashboardShowsFocusTasksFromSampleData() {
        let app = launch()
        open(.today, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["task.row"].firstMatch.waitForExistence(timeout: 5))
    }
}

/// Measures cold launch time. Results appear in the Xcode test report.
final class ProjectsLaunchPerformanceTests: XCTestCase {
    @MainActor
    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing"]
            app.launch()
        }
    }
}
#endif
