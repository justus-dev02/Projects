import XCTest

// These flows use the iPhone tab bar and swipe gestures; the Mac has its own tests
// (MacProjectsUITests).
#if os(iOS)
/// Walks through the main screens and attaches a screenshot of each one to the test report.
/// Used for visual review and App Store screenshots in every language of the test plan.
///
/// Skipped unless the environment variable `PROJECTS_SCREENSHOTS=1` is set, e.g.:
/// `TEST_RUNNER_PROJECTS_SCREENSHOTS=1 xcodebuild test -only-testing:ProjectsUITests/ScreenshotTests …`
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PROJECTS_SCREENSHOTS"] == "1", "Screenshots are only taken on request")
        continueAfterFailure = true
    }

    @MainActor
    func testCaptureMainScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed-demo-data"]
        app.launch()
        let tabs = app.tabBars.buttons

        capture("01-Today", app)

        tabs.element(boundBy: 1).tap()
        capture("02-Tasks", app)

        app.descendants(matching: .any)["task.row"].firstMatch.tap()
        capture("03-TaskDetail", app)
        app.swipeUp()
        capture("04-TaskDetail-More", app)

        tabs.element(boundBy: 2).tap()
        capture("05-Workspaces", app)
        app.buttons["workspace.row"].firstMatch.tap()
        capture("06-Workspace", app)
        app.buttons["project.row"].firstMatch.tap()
        capture("07-Board", app)

        let modes = app.segmentedControls["project.viewMode"].buttons
        if modes.count == 5 {
            modes.element(boundBy: 1).tap()
            capture("08-List", app)
            modes.element(boundBy: 2).tap()
            capture("08b-Table", app)
            modes.element(boundBy: 3).tap()
            capture("09-Calendar", app)
            modes.element(boundBy: 4).tap()
            capture("10-Timeline", app)
            modes.element(boundBy: 0).tap()
        }

        tabs.element(boundBy: 3).tap()
        capture("11-Templates", app)

        tabs.element(boundBy: 4).tap()
        capture("12-Settings", app)

        tabs.element(boundBy: 1).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tasks.new"].firstMatch.tap()
        capture("13-NewTask", app)
    }

    @MainActor
    private func capture(_ name: String, _ app: XCUIApplication) {
        sleep(1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
