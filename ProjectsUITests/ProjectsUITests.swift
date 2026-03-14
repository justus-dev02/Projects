//
//  ProjectsUITests.swift
//  ProjectsUITests
//
//  TaskFlow - UI Tests
//

import XCTest

final class ProjectsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app, appName: "TaskFlow")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Launch Tests
    func testLaunch() throws {
        app.launch()
        
        // Wait for app to launch
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
    
    // MARK: - Onboarding Tests
    func testOnboardingFlow() throws {
        app.launch()
        
        // Wait for onboarding to appear
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        
        // Navigate through onboarding pages
        for _ in 0..<3 {
            XCTAssertTrue(continueButton.exists)
            continueButton.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Last page should have "Get Started"
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3))
    }
    
    // MARK: - Dashboard Tests
    func testDashboardDisplays() throws {
        app.launch()
        
        // Skip onboarding
        skipOnboarding()
        
        // Wait for dashboard
        let dashboardTitle = app.staticTexts["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 5))
        
        // Check for stat cards
        XCTAssertTrue(app.staticTexts["Total Tasks"].exists)
        XCTAssertTrue(app.staticTexts["Completed"].exists)
        XCTAssertTrue(app.staticTexts["In Progress"].exists)
        XCTAssertTrue(app.staticTexts["Overdue"].exists)
    }
    
    // MARK: - Navigation Tests
    func testBottomTabNavigation() throws {
        app.launch()
        skipOnboarding()
        
        // Test Home tab
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.exists)
        homeTab.tap()
        XCTAssertTrue(app.staticTexts["Dashboard"].exists)
        
        // Test Workspaces tab
        let workspacesTab = app.tabBars.buttons["Workspaces"]
        XCTAssertTrue(workspacesTab.exists)
        workspacesTab.tap()
        XCTAssertTrue(app.staticTexts["Workspaces"].exists)
        
        // Test Tasks tab
        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.exists)
        tasksTab.tap()
        XCTAssertTrue(app.staticTexts["My Tasks"].exists)
        
        // Test Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }
    
    // MARK: - Workspace Tests
    func testWorkspaceList() throws {
        app.launch()
        skipOnboarding()
        
        // Navigate to Workspaces
        app.tabBars.buttons["Workspaces"].tap()
        
        // Wait for workspace list
        let workspaceList = app.lists.firstMatch
        XCTAssertTrue(workspaceList.waitForExistence(timeout: 5))
    }
    
    func testCreateWorkspace() throws {
        app.launch()
        skipOnboarding()
        
        // Navigate to Workspaces
        app.tabBars.buttons["Workspaces"].tap()
        
        // Tap New button
        let newButton = app.buttons["New"]
        if newButton.exists {
            newButton.tap()
            
            // Check for create workspace form
            let nameField = app.textFields["Name"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 3))
            
            // Enter workspace name
            nameField.tap()
            nameField.typeText("Test Workspace")
            
            // Tap Create
            let createButton = app.buttons["Create"]
            if createButton.exists {
                createButton.tap()
            }
        }
    }
    
    // MARK: - Task Tests
    func testTaskListDisplays() throws {
        app.launch()
        skipOnboarding()
        
        // Navigate to Tasks
        app.tabBars.buttons["Tasks"].tap()
        
        // Wait for task list
        let myTasksTitle = app.staticTexts["My Tasks"]
        XCTAssertTrue(myTasksTitle.waitForExistence(timeout: 5))
    }
    
    // MARK: - Settings Tests
    func testSettingsView() throws {
        app.launch()
        skipOnboarding()
        
        // Navigate to Settings
        app.tabBars.buttons["Settings"].tap()
        
        // Wait for settings
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3))
        
        // Check for profile section
        XCTAssertTrue(app.staticTexts["Profile"].exists)
        XCTAssertTrue(app.staticTexts["Preferences"].exists)
        XCTAssertTrue(app.staticTexts["About"].exists)
    }
    
    // MARK: - Search Tests
    func testSearchFunctionality() throws {
        app.launch()
        skipOnboarding()
        
        // Navigate to Workspaces
        app.tabBars.buttons["Workspaces"].tap()
        
        // Activate search
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Test")
            
            // Clear search
            let clearButton = app.buttons["Clear"]
            if clearButton.exists {
                clearButton.tap()
            }
        }
    }
    
    // MARK: - Notification Tests
    func testNotificationsView() throws {
        app.launch()
        skipOnboarding()
        
        // Navigate to dashboard first
        app.tabBars.buttons["Home"].tap()
        
        // Look for notifications button in navigation bar
        let notificationsButton = app.navigationBars.buttons["bell.fill"]
            .or(app.navigationBars.buttons["Notifications"])
        
        if notificationsButton.exists {
            notificationsButton.tap()
            
            let notificationsTitle = app.staticTexts["Notifications"]
            XCTAssertTrue(notificationsTitle.waitForExistence(timeout: 3))
        }
    }
    
    // MARK: - Dark Mode Tests
    func testDarkModeSupport() throws {
        app.launch()
        skipOnboarding()
        
        // The app should support system dark mode
        // This is a basic check - actual dark mode testing requires device configuration
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
    
    // MARK: - Accessibility Tests
    func testAccessibilityLabels() throws {
        app.launch()
        skipOnboarding()
        
        // Check that main UI elements have accessibility labels
        let dashboardTitle = app.staticTexts["Dashboard"]
        XCTAssertTrue(dashboardTitle.label.contains("Dashboard"))
        
        // Check buttons have labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(5) {
            XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label")
        }
    }
    
    // MARK: - Helper Methods
    private func skipOnboarding() {
        let continueButton = app.buttons["Continue"]
        let getStartedButton = app.buttons["Get Started"]
        
        if continueButton.waitForExistence(timeout: 3) {
            while continueButton.exists && !getStartedButton.exists {
                continueButton.tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            if getStartedButton.exists {
                getStartedButton.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
}

// MARK: - Performance Tests
final class ProjectsPerformanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
    
    func testScrollPerformance() throws {
        app.launch()
        
        // Skip onboarding
        let continueButton = app.buttons["Continue"]
        while continueButton.exists {
            continueButton.tap()
        }
        
        // Measure scroll performance
        let scrollView = app.scrollViews.firstMatch
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            scrollView.swipeUp(velocity: .fast)
            scrollView.swipeDown(velocity: .fast)
        }
    }
}
