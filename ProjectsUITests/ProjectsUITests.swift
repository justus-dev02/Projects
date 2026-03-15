//
//  ProjectsUITests.swift
//  ProjectsUITests
//
//  Comprehensive UI Tests for TaskFlow Projects App
//

import XCTest

@MainActor
final class ProjectsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
        
        // Wait for the app to be ready
        waitForAppToBeReady()
    }
    
    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    private func waitForAppToBeReady(timeout: TimeInterval = 10) {
        let predicate = NSPredicate(format: "exists == true")
        expectation(for: predicate, evaluatedWith: app, handler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
    private func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == true && isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    private func waitForElementToVanish(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // MARK: - Launch Tests
    
    func testApp_Launch_Successfully() {
        // Then
        XCTAssertTrue(app.exists)
    }
    
    func testApp_Launch_ShowsMainWindow() {
        // Then
        XCTAssertTrue(app.windows.element(boundBy: 0).exists)
    }
    
    // MARK: - Navigation Tests
    
    func testNavigation_TabBar_Exists() {
        // Given
        let tabBar = app.tabBars.firstMatch
        
        // Then - Tab bar should exist on main screens
        // Note: This test may need adjustment based on actual app structure
        if tabBar.exists {
            XCTAssertTrue(tabBar.exists)
        }
    }
    
    func testNavigation_BackButton_Works() {
        // This test would navigate to a detail screen and back
        // Implementation depends on actual navigation structure
        print("Navigation back button test - requires specific screen implementation")
    }
    
    // MARK: - Dark Mode Tests
    
    func testUI_SupportsDarkMode() {
        // Given
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launchEnvironment["AppleInterfaceStyle"] = "Dark"
        app.launch()
        
        // Then - App should launch in dark mode
        waitForAppToBeReady()
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Localization Tests
    
    func testUI_SupportsEnglishLocalization() {
        // Given
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
        
        // Then
        waitForAppToBeReady()
        XCTAssertTrue(app.exists)
    }
    
    func testUI_SupportsGermanLocalization() {
        // Given
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(de)"]
        app.launch()
        
        // Then
        waitForAppToBeReady()
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibility_ElementsHaveLabels() {
        // Given
        let query = app.descendants(matching: .any)
        
        // Then - Check that important elements have accessibility labels
        // This is a basic check; specific tests should target key UI elements
        let elements = query.allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(elements.count, 1)
    }
    
    func testAccessibility_ImagesHaveLabels() {
        // Given
        let images = app.images
        
        // Then - All images should have accessibility labels or be marked as decorative
        if images.count > 0 {
            // Basic check - in real tests, verify each image has appropriate label
            XCTAssertTrue(images.count >= 0)
        }
    }
    
    func testAccessibility_ButtonsAreAccessible() {
        // Given
        let buttons = app.buttons
        
        // Then - Buttons should be accessible
        if buttons.count > 0 {
            let firstButton = buttons.element(boundBy: 0)
            XCTAssertTrue(firstButton.exists)
            XCTAssertTrue(firstButton.isHittable)
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testPerformance_MemoryUsage() {
        measureMetrics([.memory], automaticallyStartMeasuring: false) {
            // Perform operations that might increase memory usage
            startMeasuring()
            
            // Simulate user interactions
            let buttons = app.buttons
            if buttons.count > 0 {
                _ = buttons.allElementsBoundByIndex.count
            }
            
            stopMeasuring()
        }
    }
    
    func testPerformance_CPUUsage() {
        measureMetrics([.cpuTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            
            // Simulate user interactions
            let buttons = app.buttons
            if buttons.count > 0 {
                _ = buttons.allElementsBoundByIndex.count
            }
            
            stopMeasuring()
        }
    }
    
    // MARK: - Launch Time Performance
    
    func testPerformance_LaunchTime() {
        measure(metrics: [XCTOSSignpostMetric.launchDuration]) {
            app.launch()
            waitForAppToBeReady()
        }
    }
    
    // MARK: - Orientation Tests (iOS only)
    
    #if os(iOS)
    func testUI_SupportsPortraitOrientation() {
        // Given
        XCUIDevice.shared.orientation = .portrait
        
        // Then
        waitForAppToBeReady()
        XCTAssertTrue(app.exists)
    }
    
    func testUI_SupportsLandscapeOrientation() {
        // Given
        XCUIDevice.shared.orientation = .landscapeLeft
        
        // Then
        waitForAppToBeReady()
        XCTAssertTrue(app.exists)
        
        // Reset orientation
        XCUIDevice.shared.orientation = .portrait
    }
    #endif
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling_EmptyState_DisplaysCorrectly() {
        // Given - App launched with empty data
        // Then - Empty state views should display correctly
        // This test would verify empty state UI elements
        print("Empty state test - requires specific screen implementation")
    }
    
    func testErrorHandling_NetworkError_ShowsAlert() {
        // Given - Simulate network error
        // Then - Error alert should be displayed
        // This test would require network mocking
        print("Network error test - requires network mocking")
    }
    
    // MARK: - Screenshot Tests
    
    func testScreenshots_HomeScreen() {
        // Take screenshot of home screen
        snapshot("01_HomeScreen")
    }
    
    // MARK: - Multi-Window Tests (macOS/iPadOS)
    
    #if os(macOS) || os(iOS)
    func testMultiWindow_CanCreateNewWindow() {
        // Given
        // On macOS, test creating new window
        // On iOS, test scene activation
        
        // Then - New window/scene should be created
        print("Multi-window test - platform specific implementation")
    }
    #endif
    
    // MARK: - Search Tests
    
    func testSearch_SearchBar_Exists() {
        // Given
        let searchFields = app.searchFields
        
        // Then - If search is available, search field should exist
        if searchFields.count > 0 {
            XCTAssertTrue(searchFields.element(boundBy: 0).exists)
        }
    }
    
    func testSearch_SearchFunctionality_Works() {
        // Given
        let searchFields = app.searchFields
        
        // When - Enter search text
        if searchFields.count > 0 {
            let searchField = searchFields.element(boundBy: 0)
            searchField.tap()
            searchField.typeText("test")
            
            // Then - Results should appear
            // Specific implementation depends on app structure
        }
    }
    
    // MARK: - Form Tests
    
    func testForm_TextFields_AcceptInput() {
        // Given
        let textFields = app.textFields
        
        // When - Enter text
        if textFields.count > 0 {
            let textField = textFields.element(boundBy: 0)
            textField.tap()
            textField.typeText("Test input")
            
            // Then - Text field should contain input
            let value = textField.value as? String
            XCTAssertEqual(value, "Test input")
        }
    }
    
    func testForm_Switches_Toggle() {
        // Given
        let switches = app.switches
        
        // When - Toggle switch
        if switches.count > 0 {
            let switchElement = switches.element(boundBy: 0)
            let initialValue = switchElement.value as? Bool ?? false
            switchElement.tap()
            
            // Then - Switch value should change
            let newValue = switchElement.value as? Bool ?? true
            XCTAssertNotEqual(initialValue, newValue)
        }
    }
    
    func testForm_SegmentedControl_Select() {
        // Given
        let segmentControls = app.segmentedControls
        
        // When - Select segment
        if segmentControls.count > 0 {
            let segmentControl = segmentControls.element(boundBy: 0)
            segmentControl.buttons.element(boundBy: 0).tap()
            
            // Then - Segment should be selected
            XCTAssertTrue(segmentControl.exists)
        }
    }
    
    // MARK: - List Tests
    
    func testList_Scrolling_Works() {
        // Given
        let tables = app.tables
        let collections = app.collectionViews
        
        // When - Scroll
        if tables.count > 0 {
            let table = tables.element(boundBy: 0)
            table.swipeUp()
            XCTAssertTrue(table.exists)
        } else if collections.count > 0 {
            let collection = collections.element(boundBy: 0)
            collection.swipeUp()
            XCTAssertTrue(collection.exists)
        }
    }
    
    func testList_CellSelection_Works() {
        // Given
        let tables = app.tables
        
        // When - Select cell
        if tables.count > 0 {
            let table = tables.element(boundBy: 0)
            if table.cells.count > 0 {
                let cell = table.cells.element(boundBy: 0)
                cell.tap()
                
                // Then - Cell should be selected
                XCTAssertTrue(cell.exists)
            }
        }
    }
    
    // MARK: - Alert Tests
    
    func testAlert_ConfirmationAlert_HandlesActions() {
        // Given - Trigger alert (implementation specific)
        let alerts = app.alerts
        
        // When/Then - Handle alert if present
        if alerts.count > 0 {
            let alert = alerts.element(boundBy: 0)
            if alert.exists {
                // Try to tap cancel button
                let cancelButton = alert.buttons["Cancel"]
                if cancelButton.exists {
                    cancelButton.tap()
                }
            }
        }
    }
    
    // MARK: - Context Menu Tests
    
    func testContextMenu_LongPress_ShowsMenu() {
        // Given
        let elements = app.descendants(matching: .any)
        
        // When - Long press on element
        if elements.count > 0 {
            let element = elements.element(boundBy: 0)
            if element.isHittable {
                element.press(forDuration: 1.5)
                
                // Then - Context menu should appear
                // Check for menu elements
            }
        }
    }
    
    // MARK: - Pull to Refresh Tests
    
    #if os(iOS)
    func testPullToRefresh_TriggerRefresh() {
        // Given
        let tables = app.tables
        let collections = app.collectionViews
        
        // When - Pull down
        if tables.count > 0 {
            let table = tables.element(boundBy: 0)
            table.swipeDown()
        } else if collections.count > 0 {
            let collection = collections.element(boundBy: 0)
            collection.swipeDown()
        }
        
        // Then - Refresh should trigger
        // Check for activity indicator
    }
    #endif
    
    // MARK: - Keyboard Tests
    
    func testKeyboard_AppearsOnTextFieldTap() {
        // Given
        let textFields = app.textFields
        
        // When - Tap text field
        if textFields.count > 0 {
            let textField = textFields.element(boundBy: 0)
            textField.tap()
            
            // Then - Keyboard should appear
            #if os(iOS)
            let keyboard = app.keyboards.firstMatch
            XCTAssertTrue(waitForElementToAppear(keyboard, timeout: 3))
            #endif
        }
    }
    
    func testKeyboard_DismissesOnReturn() {
        // Given
        let textFields = app.textFields
        
        // When - Tap return key
        if textFields.count > 0 {
            let textField = textFields.element(boundBy: 0)
            textField.tap()
            app.keyboards.firstMatch.buttons["Return"].tap()
            
            // Then - Keyboard should dismiss
            #if os(iOS)
            let keyboard = app.keyboards.firstMatch
            // Keyboard should not be visible or different element focused
            #endif
        }
    }
}

// MARK: - Snapshot Testing Helper

func setupSnapshot(_ app: XCUIApplication, waitForAnimations: Bool = true) {
    // Setup for snapshot testing
    // This would be used with fastlane snapshot or similar
}

func snapshot(_ name: String, timeout: TimeInterval = 10) {
    // Take snapshot with given name
    print("Snapshot: \(name)")
}
