import XCTest

#if os(macOS)
/// End-to-end flows of the Mac app: menu commands, keyboard shortcuts and the native task table.
///
/// Like the iOS tests they only use accessibility identifiers, keyboard shortcuts and text typed by
/// the test itself, so they pass in every language of the test plan.
final class MacProjectsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed-demo-data"]
        app.launch()
        app.activate()
        return app
    }

    /// Go ▸ Tasks (⌘2) and the table of the task list.
    @MainActor
    private func openTasks(in app: XCUIApplication) -> XCUIElement {
        app.typeKey("2", modifierFlags: .command)
        // SwiftUI tables appear as outlines in the macOS accessibility hierarchy.
        let table = app.outlines["tasks.list"].firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5), "The Mac shows tasks in a native table")
        return table
    }

    /// Clicks the row's title, which selects the row like a user's click.
    @MainActor
    private func select(_ row: XCUIElement) {
        row.staticTexts.element(boundBy: 0).click()
    }

    @MainActor
    private func row(titled title: String, in table: XCUIElement) -> XCUIElement {
        table.outlineRows.containing(NSPredicate(format: "value == %@", title)).firstMatch
    }

    @MainActor
    func testTaskListIsANativeTableWithSampleData() {
        let app = launch()
        let table = openTasks(in: app)
        XCTAssertGreaterThan(table.outlineRows.count, 0)
    }

    @MainActor
    func testNewTaskShortcutCreatesARow() {
        let app = launch()
        let table = openTasks(in: app)

        app.typeKey("n", modifierFlags: .command)
        let titleField = app.textFields["taskEditor.title"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.click()
        titleField.typeText("Created on the Mac")
        app.buttons["editor.save"].firstMatch.click()

        XCTAssertTrue(row(titled: "Created on the Mac", in: table).waitForExistence(timeout: 5))
    }

    @MainActor
    func testArrowKeysMoveTheSelectionAndReturnOpensTheTask() {
        let app = launch()
        let table = openTasks(in: app)
        XCTAssertGreaterThan(table.outlineRows.count, 1)
        let first = table.outlineRows.element(boundBy: 0)
        let second = table.outlineRows.element(boundBy: 1)

        select(first)
        XCTAssertTrue(first.isSelected)
        XCTAssertTrue(app.buttons["bulk.delete"].exists, "A selection shows the bulk action bar")

        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(second.isSelected)
        XCTAssertFalse(first.isSelected)

        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.buttons["taskDetail.edit"].waitForExistence(timeout: 5), "Return opens the selected task")
    }

    @MainActor
    func testDeleteKeyDeletesAndUndoRestores() {
        let app = launch()
        let table = openTasks(in: app)
        app.typeKey("n", modifierFlags: .command)
        let titleField = app.textFields["taskEditor.title"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.click()
        titleField.typeText("Delete me with the keyboard")
        app.buttons["editor.save"].firstMatch.click()
        let created = row(titled: "Delete me with the keyboard", in: table)
        XCTAssertTrue(created.waitForExistence(timeout: 5))

        select(created)
        app.typeKey(.delete, modifierFlags: [])
        XCTAssertFalse(created.waitForExistence(timeout: 2))

        app.typeKey("z", modifierFlags: .command)
        XCTAssertTrue(row(titled: "Delete me with the keyboard", in: table).waitForExistence(timeout: 5))
    }
}
#endif
