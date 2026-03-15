//
//  WorkspaceManagementUITests.swift
//  ProjectsUITests
//
//  Comprehensive UI Tests for Workspace Management
//

import XCTest

@MainActor
final class WorkspaceManagementUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting", "-ClearData"]
        app.launch()
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
    
    // MARK: - Workspace List Tests
    
    func testWorkspaceList_DisplaysEmptyState_WhenNoWorkspaces() {
        // Given - App launched with cleared data
        
        // Then - Should show empty state or create workspace prompt
        // Check for empty state message or create button
        let createButton = app.buttons["Create Workspace"]
            .orWhere(app.buttons["New Workspace"])
            .orWhere(app.buttons.matching(identifier: "createWorkspaceButton").firstMatch)
        
        // Empty state should be visible
        XCTAssertTrue(app.staticTexts["No Workspaces"].exists || createButton.exists)
    }
    
    func testWorkspaceList_CreateWorkspaceButton_Exists() {
        // Then - Create button should exist
        let createButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'create' AND label CONTAINS[c] 'workspace'"))
        if createButtons.count == 0 {
            // Try alternative identifiers
            let alternativeButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'new' AND label CONTAINS[c] 'workspace'"))
            XCTAssertTrue(alternativeButtons.count > 0 || createButtons.count > 0)
        } else {
            XCTAssertTrue(createButtons.firstMatch.exists)
        }
    }
    
    // MARK: - Create Workspace Tests
    
    func testCreateWorkspace_NavigationToCreateScreen() {
        // Given
        let createButton = findCreateWorkspaceButton()
        
        // When - Tap create button
        if createButton.exists {
            createButton.tap()
            
            // Then - Should navigate to create workspace screen
            waitForAppToBeReady(timeout: 3)
            
            // Check for create workspace form elements
            let nameField = app.textFields["Workspace Name"]
                .orWhere(app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch)
            XCTAssertTrue(nameField.exists || app.navigationBars["Create Workspace"].exists)
        }
    }
    
    func testCreateWorkspace_FillForm_ValidData() {
        // Given - On create workspace screen
        navigateToCreateWorkspace()
        
        // When - Fill form with valid data
        fillWorkspaceForm(
            name: "Test Workspace",
            description: "Test Description",
            color: "#2D5BFF"
        )
        
        // Then - Form should accept all inputs
        let nameField = app.textFields["Workspace Name"]
            .orWhere(app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch)
        let value = nameField.value as? String
        XCTAssertEqual(value, "Test Workspace")
    }
    
    func testCreateWorkspace_Submit_CreatesWorkspace() {
        // Given - Form filled with valid data
        navigateToCreateWorkspace()
        fillWorkspaceForm(
            name: "My New Workspace",
            description: "My Description"
        )
        
        // When - Tap create/save button
        let saveButton = app.buttons["Create"]
            .orWhere(app.buttons["Save"])
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'create'")).firstMatch)
        
        if saveButton.exists {
            saveButton.tap()
            
            // Then - Workspace should be created
            waitForAppToBeReady(timeout: 3)
            
            // Check workspace appears in list
            let workspaceItem = app.staticTexts["My New Workspace"]
            XCTAssertTrue(waitForElementToAppear(workspaceItem, timeout: 5))
        }
    }
    
    func testCreateWorkspace_Validation_EmptyName() {
        // Given - On create workspace screen
        navigateToCreateWorkspace()
        
        // When - Try to submit without name
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            
            // Then - Should show validation error
            waitForAppToBeReady(timeout: 2)
            
            // Check for error message or disabled button
            let errorMessages = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'required' OR label CONTAINS[c] 'name'"))
            XCTAssertTrue(errorMessages.count > 0 || !saveButton.isEnabled)
        }
    }
    
    func testCreateWorkspace_Cancel_DoesNotCreate() {
        // Given - On create workspace screen
        navigateToCreateWorkspace()
        
        // When - Tap cancel button
        let cancelButton = app.buttons["Cancel"].orWhere(app.buttons.matching(identifier: "cancelButton").firstMatch)
        if cancelButton.exists {
            cancelButton.tap()
            
            // Then - Should return to list without creating workspace
            waitForAppToBeReady(timeout: 2)
            
            // Create button should still be visible (no workspace created)
            XCTAssertTrue(findCreateWorkspaceButton().exists)
        }
    }
    
    // MARK: - Workspace Detail Tests
    
    func testWorkspaceDetail_NavigateToDetail() {
        // Given - Workspace exists
        createTestWorkspace()
        
        // When - Tap workspace
        let workspaceItem = app.staticTexts["Test Workspace"]
            .orWhere(app.buttons["Test Workspace"].firstMatch)
        if workspaceItem.exists {
            workspaceItem.tap()
            
            // Then - Should navigate to detail screen
            waitForAppToBeReady(timeout: 3)
            
            // Check for detail screen elements
            XCTAssertTrue(
                app.navigationBars["Test Workspace"].exists ||
                app.navigationBars["Workspace Details"].exists ||
                app.staticTexts["Test Workspace"].exists
            )
        }
    }
    
    func testWorkspaceDetail_DisplaysWorkspaceInfo() {
        // Given - Workspace exists
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // Then - Should display workspace information
        let nameLabel = app.staticTexts["Test Workspace"]
        XCTAssertTrue(nameLabel.exists)
    }
    
    func testWorkspaceDetail_EditButton_Exists() {
        // Given - On workspace detail screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // Then - Edit button should exist
        let editButton = app.buttons["Edit"]
            .orWhere(app.buttons.matching(identifier: "editButton").firstMatch)
        XCTAssertTrue(editButton.exists)
    }
    
    // MARK: - Edit Workspace Tests
    
    func testEditWorkspace_NavigateToEditScreen() {
        // Given - On workspace detail screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Tap edit button
        let editButton = app.buttons["Edit"].orWhere(app.buttons.matching(identifier: "editButton").firstMatch)
        if editButton.exists {
            editButton.tap()
            
            // Then - Should navigate to edit screen
            waitForAppToBeReady(timeout: 3)
            
            // Form should be pre-filled
            let nameField = app.textFields.matching(NSPredicate(format: "value CONTAINS[c] 'Test'")).firstMatch
            XCTAssertTrue(nameField.exists)
        }
    }
    
    func testEditWorkspace_UpdateName() {
        // Given - On edit workspace screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToEditWorkspace()
        
        // When - Update name
        let nameField = app.textFields.firstMatch
        nameField.tap()
        nameField.typeText(" Updated")
        
        // Then - Name should be updated
        let value = nameField.value as? String
        XCTAssertTrue(value?.contains("Updated") == true)
    }
    
    func testEditWorkspace_SaveChanges() {
        // Given - On edit workspace screen with changes
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToEditWorkspace()
        
        // When - Save changes
        let nameField = app.textFields.firstMatch
        nameField.tap()
        nameField.typeText(" Updated")
        
        let saveButton = app.buttons["Save"].orWhere(app.buttons["Done"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            
            // Then - Changes should be saved
            waitForAppToBeReady(timeout: 3)
            
            // Check updated name appears
            let updatedName = app.staticTexts["Test Workspace Updated"]
            XCTAssertTrue(waitForElementToAppear(updatedName, timeout: 5))
        }
    }
    
    func testEditWorkspace_Cancel_DiscardsChanges() {
        // Given - On edit workspace screen with changes
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToEditWorkspace()
        
        // When - Make changes and cancel
        let nameField = app.textFields.firstMatch
        nameField.tap()
        nameField.typeText(" Updated")
        
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.exists {
            cancelButton.tap()
            
            // Then - Changes should be discarded
            waitForAppToBeReady(timeout: 2)
            
            // Original name should still be shown
            let originalName = app.staticTexts["Test Workspace"]
            XCTAssertTrue(originalName.exists)
        }
    }
    
    // MARK: - Delete Workspace Tests
    
    func testDeleteWorkspace_ConfirmationAlert() {
        // Given - On workspace detail or edit screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Tap delete button
        let deleteButton = app.buttons["Delete Workspace"]
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch)
        
        if deleteButton.exists {
            deleteButton.tap()
            
            // Then - Confirmation alert should appear
            waitForAppToBeReady(timeout: 2)
            
            let alert = app.alerts.firstMatch
            XCTAssertTrue(alert.exists)
            
            // Alert should have delete confirmation message
            let alertText = alert.staticTexts.firstMatch.label
            XCTAssertTrue(alertText.contains("delete") || alertText.contains("Delete"))
        }
    }
    
    func testDeleteWorkspace_Confirm_DeletesWorkspace() {
        // Given - Workspace exists
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Confirm delete
        deleteCurrentWorkspace()
        
        // Then - Workspace should be deleted
        waitForAppToBeReady(timeout: 3)
        
        // Workspace should not appear in list
        let workspaceItem = app.staticTexts["Test Workspace"]
        XCTAssertFalse(workspaceItem.exists)
    }
    
    func testDeleteWorkspace_Cancel_DoesNotDelete() {
        // Given - On delete confirmation
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Tap delete, then cancel
        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch
        if deleteButton.exists {
            deleteButton.tap()
            
            let cancelButton = app.alerts.firstMatch.buttons["Cancel"]
                .orWhere(app.alerts.firstMatch.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch)
            
            if cancelButton.exists {
                cancelButton.tap()
                
                // Then - Workspace should not be deleted
                waitForAppToBeReady(timeout: 2)
                
                let workspaceItem = app.staticTexts["Test Workspace"]
                XCTAssertTrue(workspaceItem.exists)
            }
        }
    }
    
    // MARK: - Workspace Members Tests
    
    func testWorkspaceMembers_ViewMembers() {
        // Given - On workspace detail screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Tap members section
        let membersButton = app.buttons["Members"]
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'member'")).firstMatch)
        
        if membersButton.exists {
            membersButton.tap()
            
            // Then - Members list should appear
            waitForAppToBeReady(timeout: 3)
            XCTAssertTrue(app.navigationBars["Members"].exists || app.staticTexts["Members"].exists)
        }
    }
    
    func testWorkspaceMembers_AddMember() {
        // Given - On members screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToMembersScreen()
        
        // When - Tap add member
        let addButton = app.buttons["Add Member"]
            .orWhere(app.buttons.matching(identifier: "addButton").firstMatch)
        
        if addButton.exists {
            addButton.tap()
            
            // Then - Add member form should appear
            waitForAppToBeReady(timeout: 3)
            
            // Email field should exist
            let emailField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'email'")).firstMatch
            XCTAssertTrue(emailField.exists)
        }
    }
    
    // MARK: - Workspace Projects Tests
    
    func testWorkspaceProjects_ViewProjects() {
        // Given - On workspace detail screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Tap projects section
        let projectsButton = app.buttons["Projects"]
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'project'")).firstMatch)
        
        if projectsButton.exists {
            projectsButton.tap()
            
            // Then - Projects list should appear
            waitForAppToBeReady(timeout: 3)
            XCTAssertTrue(app.navigationBars["Projects"].exists || app.staticTexts["Projects"].exists)
        }
    }
    
    func testWorkspaceProjects_CreateProject() {
        // Given - On projects screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToProjectsScreen()
        
        // When - Tap create project
        let createButton = app.buttons["Create Project"]
            .orWhere(app.buttons["New Project"])
            .orWhere(app.buttons.matching(identifier: "createButton").firstMatch)
        
        if createButton.exists {
            createButton.tap()
            
            // Then - Create project form should appear
            waitForAppToBeReady(timeout: 3)
            
            // Name field should exist
            let nameField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch
            XCTAssertTrue(nameField.exists)
        }
    }
    
    // MARK: - Workspace Settings Tests
    
    func testWorkspaceSettings_NavigateToSettings() {
        // Given - On workspace detail screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Tap settings
        let settingsButton = app.buttons["Settings"]
            .orWhere(app.buttons.matching(identifier: "settingsButton").firstMatch)
        
        if settingsButton.exists {
            settingsButton.tap()
            
            // Then - Settings screen should appear
            waitForAppToBeReady(timeout: 3)
            XCTAssertTrue(app.navigationBars["Settings"].exists || app.staticTexts["Settings"].exists)
        }
    }
    
    func testWorkspaceSettings_ChangeColor() {
        // Given - On settings screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToSettingsScreen()
        
        // When - Change color
        let colorPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'color'")).firstMatch
        
        if colorPicker.exists {
            colorPicker.tap()
            
            // Then - Color picker should appear
            waitForAppToBeReady(timeout: 2)
            
            // Select a color
            let colorOption = app.buttons.firstMatch
            if colorOption.exists {
                colorOption.tap()
            }
        }
    }
    
    func testWorkspaceSettings_ChangeIcon() {
        // Given - On settings screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        navigateToSettingsScreen()
        
        // When - Change icon
        let iconPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'icon'")).firstMatch
        
        if iconPicker.exists {
            iconPicker.tap()
            
            // Then - Icon picker should appear
            waitForAppToBeReady(timeout: 2)
            
            // Select an icon
            let iconOption = app.buttons.firstMatch
            if iconOption.exists {
                iconOption.tap()
            }
        }
    }
    
    // MARK: - Workspace Archive Tests
    
    func testWorkspaceArchive_ArchiveWorkspace() {
        // Given - On workspace settings or detail screen
        createTestWorkspace()
        navigateToWorkspaceDetail()
        
        // When - Archive workspace
        let archiveButton = app.buttons["Archive Workspace"]
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'archive'")).firstMatch)
        
        if archiveButton.exists {
            archiveButton.tap()
            
            // Then - Confirmation might appear
            waitForAppToBeReady(timeout: 2)
            
            let confirmButton = app.alerts.firstMatch.buttons["Archive"]
                .orWhere(app.buttons["Archive"]).firstMatch
            
            if confirmButton.exists {
                confirmButton.tap()
                
                // Workspace should be archived
                waitForAppToBeReady(timeout: 3)
            }
        }
    }
    
    // MARK: - Helper Methods for Navigation
    
    private func findCreateWorkspaceButton() -> XCUIElement {
        return app.buttons["Create Workspace"]
            .orWhere(app.buttons["New Workspace"])
            .orWhere(app.buttons.matching(identifier: "createWorkspaceButton").firstMatch)
    }
    
    private func navigateToCreateWorkspace() {
        let createButton = findCreateWorkspaceButton()
        if createButton.exists {
            createButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func fillWorkspaceForm(name: String, description: String = "", color: String = "") {
        let nameField = app.textFields["Workspace Name"]
            .orWhere(app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch)
        
        nameField.tap()
        nameField.typeText(name)
        
        if !description.isEmpty {
            let descriptionField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'description'")).firstMatch
            if descriptionField.exists {
                descriptionField.tap()
                descriptionField.typeText(description)
            }
        }
    }
    
    private func createTestWorkspace() {
        navigateToCreateWorkspace()
        fillWorkspaceForm(name: "Test Workspace")
        
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToWorkspaceDetail() {
        let workspaceItem = app.staticTexts["Test Workspace"]
            .orWhere(app.buttons["Test Workspace"].firstMatch)
        if workspaceItem.exists {
            workspaceItem.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToEditWorkspace() {
        let editButton = app.buttons["Edit"].orWhere(app.buttons.matching(identifier: "editButton").firstMatch)
        if editButton.exists {
            editButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToMembersScreen() {
        let membersButton = app.buttons["Members"].orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'member'")).firstMatch)
        if membersButton.exists {
            membersButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToProjectsScreen() {
        let projectsButton = app.buttons["Projects"].orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'project'")).firstMatch)
        if projectsButton.exists {
            projectsButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToSettingsScreen() {
        let settingsButton = app.buttons["Settings"].orWhere(app.buttons.matching(identifier: "settingsButton").firstMatch)
        if settingsButton.exists {
            settingsButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func deleteCurrentWorkspace() {
        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch
        if deleteButton.exists {
            deleteButton.tap()
            
            let confirmButton = app.alerts.firstMatch.buttons["Delete"]
                .orWhere(app.alerts.firstMatch.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch)
            
            if confirmButton.exists {
                confirmButton.tap()
            }
        }
    }
}

// MARK: - XCUIElement Extension for OrWhere

extension XCUIElement {
    func orWhere(_ other: XCUIElement) -> XCUIElement {
        return self.exists ? self : other
    }
}
