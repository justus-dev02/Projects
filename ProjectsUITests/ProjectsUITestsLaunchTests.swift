//
//  ProjectsUITestsLaunchTests.swift
//  ProjectsUITests
//
//  TaskFlow - Launch Tests
//

import XCTest

final class ProjectsUITestsLaunchTests: XCTestCase {
    
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Insert steps here to perform after app launch
        
        // Take a snapshot of the app for the App Store preview
        // snapshot("01-Launch")
        
        // Verify app launched successfully
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }
}
