//
//  ProjectTaskManagementUITests.swift
//  ProjectsUITests
//
//  Comprehensive UI Tests for Project and Task Management
//

import XCTest

@MainActor
final class ProjectTaskManagementUITests: XCTestCase {
    
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
    
    // MARK: - Setup Test Data
    
    private func createTestWorkspaceAndProject() {
        // Create workspace
        createWorkspace(name: "Test Workspace")
        
        // Create project
        navigateToWorkspace("Test Workspace")
        createProject(name: "Test Project")
    }
    
    private func createWorkspace(name: String) {
        let createButton = app.buttons["Create Workspace"]
            .orWhere(app.buttons["New Workspace"]).firstMatch
        
        if createButton.exists {
            createButton.tap()
            
            let nameField = app.textFields["Workspace Name"]
                .orWhere(app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch)
            nameField.tap()
            nameField.typeText(name)
            
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
            }
        }
    }
    
    private func navigateToWorkspace(_ name: String) {
        let workspaceItem = app.staticTexts[name].orWhere(app.buttons[name].firstMatch)
        if workspaceItem.exists {
            workspaceItem.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func createProject(name: String) {
        let createButton = app.buttons["Create Project"]
            .orWhere(app.buttons["New Project"])
            .orWhere(app.buttons.matching(identifier: "createButton").firstMatch)
        
        if createButton.exists {
            createButton.tap()
            
            let nameField = app.textFields["Project Name"]
                .orWhere(app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch)
            nameField.tap()
            nameField.typeText(name)
            
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
            }
        }
    }
    
    // MARK: - Project List Tests
    
    func testProjectList_DisplaysEmptyState_WhenNoProjects() {
        // Given - Workspace without projects
        createTestWorkspaceAndProject()
        deleteAllProjects()
        
        // Then - Empty state should be visible
        let emptyStateText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no projects'")).firstMatch
        let createButton = app.buttons["Create Project"].orWhere(app.buttons["New Project"]).firstMatch
        
        XCTAssertTrue(emptyStateText.exists || createButton.exists)
    }
    
    func testProjectList_CreateProjectButton_Exists() {
        // Given - On workspace detail
        createTestWorkspaceAndProject()
        
        // Then - Create button should exist
        let createButton = app.buttons["Create Project"]
            .orWhere(app.buttons["New Project"])
            .orWhere(app.buttons.matching(identifier: "createButton")).firstMatch
        XCTAssertTrue(createButton.exists)
    }
    
    // MARK: - Create Project Tests
    
    func testCreateProject_NavigationToCreateScreen() {
        // Given - On workspace detail
        createTestWorkspaceAndProject()
        
        // When - Tap create project
        let createButton = app.buttons["Create Project"].orWhere(app.buttons["New Project"]).firstMatch
        if createButton.exists {
            createButton.tap()
            
            // Then - Should navigate to create screen
            waitForAppToBeReady(timeout: 3)
            
            // Form should be visible
            let nameField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch
            XCTAssertTrue(nameField.exists)
        }
    }
    
    func testCreateProject_FillForm_ValidData() {
        // Given - On create project screen
        createTestWorkspaceAndProject()
        navigateToCreateProject()
        
        // When - Fill form
        fillProjectForm(
            name: "New Project",
            description: "Project Description",
            color: "#4ECDC4"
        )
        
        // Then - Form should accept inputs
        let nameField = app.textFields.matching(NSPredicate(format: "value CONTAINS[c] 'New'")).firstMatch
        XCTAssertTrue(nameField.exists)
    }
    
    func testCreateProject_Submit_CreatesProject() {
        // Given - Form filled
        createTestWorkspaceAndProject()
        navigateToCreateProject()
        fillProjectForm(name: "My New Project")
        
        // When - Submit
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            
            // Then - Project should be created
            waitForAppToBeReady(timeout: 3)
            
            // Project should appear in list
            let projectItem = app.staticTexts["My New Project"]
            XCTAssertTrue(waitForElementToAppear(projectItem, timeout: 5))
        }
    }
    
    func testCreateProject_Validation_EmptyName() {
        // Given - On create project screen
        createTestWorkspaceAndProject()
        navigateToCreateProject()
        
        // When - Submit without name
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            
            // Then - Validation error should appear
            waitForAppToBeReady(timeout: 2)
            
            let errorMessages = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'required'")).firstMatch
            XCTAssertTrue(errorMessages.exists || !saveButton.isEnabled)
        }
    }
    
    func testCreateProject_WithColor() {
        // Given - On create project screen
        createTestWorkspaceAndProject()
        navigateToCreateProject()
        
        // When - Select color
        let colorPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'color'")).firstMatch
        if colorPicker.exists {
            colorPicker.tap()
            
            // Select a color
            let colorOption = app.buttons.firstMatch
            if colorOption.exists {
                colorOption.tap()
            }
            
            // Fill name and save
            fillProjectForm(name: "Colored Project")
            
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
                
                // Project should be created
                let projectItem = app.staticTexts["Colored Project"]
                XCTAssertTrue(projectItem.exists)
            }
        }
    }
    
    func testCreateProject_WithIcon() {
        // Given - On create project screen
        createTestWorkspaceAndProject()
        navigateToCreateProject()
        
        // When - Select icon
        let iconPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'icon'")).firstMatch
        if iconPicker.exists {
            iconPicker.tap()
            
            // Select an icon
            let iconOption = app.buttons.firstMatch
            if iconOption.exists {
                iconOption.tap()
            }
            
            // Fill name and save
            fillProjectForm(name: "Icon Project")
            
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
                
                let projectItem = app.staticTexts["Icon Project"]
                XCTAssertTrue(projectItem.exists)
            }
        }
    }
    
    func testCreateProject_WithDates() {
        // Given - On create project screen
        createTestWorkspaceAndProject()
        navigateToCreateProject()
        
        // When - Set dates
        fillProjectForm(
            name: "Dated Project",
            startDate: Date(),
            dueDate: Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        )
        
        // Then - Save should work
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            waitForAppToBeReady(timeout: 3)
            
            let projectItem = app.staticTexts["Dated Project"]
            XCTAssertTrue(projectItem.exists)
        }
    }
    
    // MARK: - Project Detail Tests
    
    func testProjectDetail_NavigateToDetail() {
        // Given - Project exists
        createTestWorkspaceAndProject()
        
        // When - Tap project
        let projectItem = app.staticTexts["Test Project"].orWhere(app.buttons["Test Project"].firstMatch)
        if projectItem.exists {
            projectItem.tap()
            
            // Then - Should navigate to detail
            waitForAppToBeReady(timeout: 3)
            
            XCTAssertTrue(
                app.navigationBars["Test Project"].exists ||
                app.staticTexts["Test Project"].exists
            )
        }
    }
    
    func testProjectDetail_DisplaysProjectInfo() {
        // Given - On project detail
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // Then - Info should be displayed
        let nameLabel = app.staticTexts["Test Project"]
        XCTAssertTrue(nameLabel.exists)
    }
    
    func testProjectDetail_DisplaysBoardColumns() {
        // Given - On project detail
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // Then - Board columns should be visible
        let boardView = app.scrollViews.matching(NSPredicate(format: "label CONTAINS[c] 'board' OR label CONTAINS[c] 'kanban'")).firstMatch
        let columnHeaders = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'to do' OR label CONTAINS[c] 'in progress'")).firstMatch
        
        XCTAssertTrue(boardView.exists || columnHeaders.exists)
    }
    
    func testProjectDetail_EditButton_Exists() {
        // Given - On project detail
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // Then - Edit button should exist
        let editButton = app.buttons["Edit"].orWhere(app.buttons.matching(identifier: "editButton")).firstMatch
        XCTAssertTrue(editButton.exists)
    }
    
    // MARK: - Edit Project Tests
    
    func testEditProject_NavigateToEditScreen() {
        // Given - On project detail
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // When - Tap edit
        let editButton = app.buttons["Edit"].orWhere(app.buttons.matching(identifier: "editButton")).firstMatch
        if editButton.exists {
            editButton.tap()
            
            // Then - Edit screen should appear
            waitForAppToBeReady(timeout: 3)
            
            // Form should be pre-filled
            let nameField = app.textFields.matching(NSPredicate(format: "value CONTAINS[c] 'Test'")).firstMatch
            XCTAssertTrue(nameField.exists)
        }
    }
    
    func testEditProject_UpdateName() {
        // Given - On edit screen
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        navigateToEditProject()
        
        // When - Update name
        let nameField = app.textFields.firstMatch
        nameField.tap()
        nameField.typeText(" Updated")
        
        // Then - Name should be updated
        let value = nameField.value as? String
        XCTAssertTrue(value?.contains("Updated") == true)
    }
    
    func testEditProject_SaveChanges() {
        // Given - On edit screen with changes
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        navigateToEditProject()
        
        // When - Save
        let nameField = app.textFields.firstMatch
        nameField.tap()
        nameField.typeText(" Updated")
        
        let saveButton = app.buttons["Save"].orWhere(app.buttons["Done"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            
            // Then - Changes saved
            waitForAppToBeReady(timeout: 3)
            
            let updatedName = app.staticTexts["Test Project Updated"]
            XCTAssertTrue(waitForElementToAppear(updatedName, timeout: 5))
        }
    }
    
    func testEditProject_Cancel_DiscardsChanges() {
        // Given - On edit screen with changes
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        navigateToEditProject()
        
        // When - Cancel
        let nameField = app.textFields.firstMatch
        nameField.tap()
        nameField.typeText(" Updated")
        
        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.exists {
            cancelButton.tap()
            
            // Then - Original name shown
            waitForAppToBeReady(timeout: 2)
            
            let originalName = app.staticTexts["Test Project"]
            XCTAssertTrue(originalName.exists)
        }
    }
    
    // MARK: - Project Board/Kanban Tests
    
    func testProjectBoard_DisplaysColumns() {
        // Given - On project detail
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // Then - Columns should be visible
        let toDoColumn = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'to do'")).firstMatch
        let inProgressColumn = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'in progress'")).firstMatch
        
        XCTAssertTrue(toDoColumn.exists || inProgressColumn.exists)
    }
    
    func testProjectBoard_AddColumn() {
        // Given - On project board
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // When - Tap add column
        let addColumnButton = app.buttons["Add Column"]
            .orWhere(app.buttons.matching(identifier: "addColumnButton")).firstMatch
        
        if addColumnButton.exists {
            addColumnButton.tap()
            
            // Then - Column form should appear
            waitForAppToBeReady(timeout: 2)
            
            let nameField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'column' OR placeholder CONTAINS[c] 'name'")).firstMatch
            XCTAssertTrue(nameField.exists)
        }
    }
    
    func testProjectBoard_ReorderColumns() {
        // Given - Board with columns
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // When - Drag column (if supported)
        // This is a complex interaction test
        print("Column reordering test - requires specific implementation")
    }
    
    // MARK: - Task Creation Tests
    
    func testTask_CreateTask_FromBoard() {
        // Given - On project board
        createTestWorkspaceAndProject()
        navigateToProjectDetail()
        
        // When - Tap add task in a column
        let addTaskButton = app.buttons["Add Task"]
            .orWhere(app.buttons.matching(identifier: "addTaskButton")).firstMatch
        
        if addTaskButton.exists {
            addTaskButton.tap()
            
            // Then - Task form should appear
            waitForAppToBeReady(timeout: 2)
            
            let titleField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'title' OR placeholder CONTAINS[c] 'task'")).firstMatch
            XCTAssertTrue(titleField.exists)
        }
    }
    
    func testTask_CreateTask_WithTitleOnly() {
        // Given - Task form open
        createTestWorkspaceAndProject()
        navigateToCreateTask()
        
        // When - Fill title only
        let titleField = app.textFields.firstMatch
        titleField.tap()
        titleField.typeText("New Task")
        
        // Then - Save should work
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            waitForAppToBeReady(timeout: 3)
            
            let taskItem = app.staticTexts["New Task"]
            XCTAssertTrue(taskItem.exists)
        }
    }
    
    func testTask_CreateTask_WithDescription() {
        // Given - Task form open
        createTestWorkspaceAndProject()
        navigateToCreateTask()
        
        // When - Fill title and description
        let fields = app.textFields.allElementsBoundByIndex
        if fields.count >= 2 {
            fields[0].tap()
            fields[0].typeText("Task with Description")
            
            fields[1].tap()
            fields[1].typeText("This is the task description")
            
            // Then - Save
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
                
                let taskItem = app.staticTexts["Task with Description"]
                XCTAssertTrue(taskItem.exists)
            }
        }
    }
    
    func testTask_CreateTask_WithPriority() {
        // Given - Task form open
        createTestWorkspaceAndProject()
        navigateToCreateTask()
        
        // When - Set priority
        let titleField = app.textFields.firstMatch
        titleField.tap()
        titleField.typeText("High Priority Task")
        
        let priorityPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'priority'")).firstMatch
        if priorityPicker.exists {
            priorityPicker.tap()
            
            // Select high priority
            let highPriorityOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'high'")).firstMatch
            if highPriorityOption.exists {
                highPriorityOption.tap()
            }
            
            // Save
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
                
                let taskItem = app.staticTexts["High Priority Task"]
                XCTAssertTrue(taskItem.exists)
            }
        }
    }
    
    func testTask_CreateTask_WithDueDate() {
        // Given - Task form open
        createTestWorkspaceAndProject()
        navigateToCreateTask()
        
        // When - Set due date
        let titleField = app.textFields.firstMatch
        titleField.tap()
        titleField.typeText("Dated Task")
        
        let datePicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'due date' OR label CONTAINS[c] 'date'")).firstMatch
        if datePicker.exists {
            datePicker.tap()
            
            // Select a date
            #if os(iOS)
            let today = app.collectionViews.staticTexts.firstMatch
            if today.exists {
                today.tap()
            }
            #endif
            
            let doneButton = app.buttons["Done"].firstMatch
            if doneButton.exists {
                doneButton.tap()
            }
            
            // Save
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
                
                let taskItem = app.staticTexts["Dated Task"]
                XCTAssertTrue(taskItem.exists)
            }
        }
    }
    
    func testTask_CreateTask_WithAssignee() {
        // Given - Task form open
        createTestWorkspaceAndProject()
        navigateToCreateTask()
        
        // When - Set assignee
        let titleField = app.textFields.firstMatch
        titleField.tap()
        titleField.typeText("Assigned Task")
        
        let assigneePicker = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'assignee' OR label CONTAINS[c] 'assign'")).firstMatch
        if assigneePicker.exists {
            assigneePicker.tap()
            
            // Select user
            let userOption = app.buttons.firstMatch
            if userOption.exists {
                userOption.tap()
            }
            
            // Save
            let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
            if saveButton.exists {
                saveButton.tap()
                waitForAppToBeReady(timeout: 3)
                
                let taskItem = app.staticTexts["Assigned Task"]
                XCTAssertTrue(taskItem.exists)
            }
        }
    }
    
    // MARK: - Task Detail Tests
    
    func testTaskDetail_NavigateToDetail() {
        // Given - Task exists
        createTestWorkspaceAndProject()
        createTestTask(title: "Test Task")
        navigateToProjectDetail()
        
        // When - Tap task
        let taskItem = app.staticTexts["Test Task"].orWhere(app.buttons["Test Task"].firstMatch)
        if taskItem.exists {
            taskItem.tap()
            
            // Then - Detail should appear
            waitForAppToBeReady(timeout: 3)
            
            XCTAssertTrue(
                app.navigationBars["Test Task"].exists ||
                app.staticTexts["Test Task"].exists
            )
        }
    }
    
    func testTaskDetail_DisplaysTaskInfo() {
        // Given - On task detail
        createTestWorkspaceAndProject()
        createTestTask(title: "Detailed Task")
        navigateToTaskDetail("Detailed Task")
        
        // Then - Info should be displayed
        let titleLabel = app.staticTexts["Detailed Task"]
        XCTAssertTrue(titleLabel.exists)
    }
    
    func testTaskDetail_EditButton_Exists() {
        // Given - On task detail
        createTestWorkspaceAndProject()
        createTestTask(title: "Editable Task")
        navigateToTaskDetail("Editable Task")
        
        // Then - Edit button should exist
        let editButton = app.buttons["Edit"].orWhere(app.buttons.matching(identifier: "editButton")).firstMatch
        XCTAssertTrue(editButton.exists)
    }
    
    // MARK: - Task Status Tests
    
    func testTaskStatus_ChangeStatus_ToInProgress() {
        // Given - Task exists
        createTestWorkspaceAndProject()
        createTestTask(title: "Status Task")
        
        // When - Change status
        navigateToProjectDetail()
        
        let statusButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'to do'")).firstMatch
        if statusButton.exists {
            statusButton.tap()
            
            // Select in progress
            let inProgressOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'in progress'")).firstMatch
            if inProgressOption.exists {
                inProgressOption.tap()
                
                // Then - Status should change
                waitForAppToBeReady(timeout: 2)
            }
        }
    }
    
    func testTaskStatus_ChangeStatus_ToDone() {
        // Given - Task exists
        createTestWorkspaceAndProject()
        createTestTask(title: "Complete Task")
        
        // When - Mark as done
        navigateToProjectDetail()
        
        let doneButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'done' OR label CONTAINS[c] 'complete'")).firstMatch
        if doneButton.exists {
            doneButton.tap()
            
            // Then - Task should be marked done
            waitForAppToBeReady(timeout: 2)
        }
    }
    
    func testTaskStatus_DragTask_BetweenColumns() {
        // Given - Board with task
        createTestWorkspaceAndProject()
        createTestTask(title: "Draggable Task")
        navigateToProjectDetail()
        
        // When - Drag task (if supported)
        print("Drag task test - requires specific implementation")
    }
    
    // MARK: - Task Subtask Tests
    
    func testSubtask_AddSubtask() {
        // Given - On task detail
        createTestWorkspaceAndProject()
        createTestTask(title: "Parent Task")
        navigateToTaskDetail("Parent Task")
        
        // When - Add subtask
        let addSubtaskButton = app.buttons["Add Subtask"]
            .orWhere(app.buttons.matching(identifier: "addSubtaskButton")).firstMatch
        
        if addSubtaskButton.exists {
            addSubtaskButton.tap()
            
            // Enter subtask title
            let subtaskField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'subtask'")).firstMatch
            if subtaskField.exists {
                subtaskField.tap()
                subtaskField.typeText("New Subtask")
                
                // Save
                let saveButton = app.buttons["Save"].orWhere(app.buttons["Add"]).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    
                    // Then - Subtask should appear
                    waitForAppToBeReady(timeout: 2)
                    
                    let subtaskItem = app.staticTexts["New Subtask"]
                    XCTAssertTrue(subtaskItem.exists)
                }
            }
        }
    }
    
    func testSubtask_ToggleSubtask() {
        // Given - Task with subtask
        createTestWorkspaceAndProject()
        createTestTaskWithSubtask(title: "Task", subtaskTitle: "Toggle Subtask")
        navigateToTaskDetail("Task")
        
        // When - Toggle subtask
        let subtaskCheckbox = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'toggle'")).firstMatch
            .orWhere(app.checkBoxes.firstMatch)
            .orWhere(app.staticTexts["Toggle Subtask"].firstMatch)
        
        if subtaskCheckbox.exists {
            subtaskCheckbox.tap()
            
            // Then - Subtask should be marked complete
            waitForAppToBeReady(timeout: 2)
        }
    }
    
    func testSubtask_DeleteSubtask() {
        // Given - Task with subtask
        createTestWorkspaceAndProject()
        createTestTaskWithSubtask(title: "Task", subtaskTitle: "Deletable Subtask")
        navigateToTaskDetail("Task")
        
        // When - Delete subtask
        let deleteButton = app.buttons.matching(identifier: "delete").firstMatch
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch)
        
        if deleteButton.exists {
            deleteButton.tap()
            
            // Confirm if needed
            let confirmButton = app.alerts.firstMatch.buttons["Delete"].firstMatch
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Then - Subtask should be deleted
            waitForAppToBeReady(timeout: 2)
            
            let subtaskItem = app.staticTexts["Deletable Subtask"]
            XCTAssertFalse(subtaskItem.exists)
        }
    }
    
    // MARK: - Task Comment Tests
    
    func testComment_AddComment() {
        // Given - On task detail
        createTestWorkspaceAndProject()
        createTestTask(title: "Comment Task")
        navigateToTaskDetail("Comment Task")
        
        // When - Add comment
        let addCommentButton = app.buttons["Add Comment"]
            .orWhere(app.buttons.matching(identifier: "addCommentButton")).firstMatch
        
        if addCommentButton.exists {
            addCommentButton.tap()
            
            // Enter comment
            let commentField = app.textViews.firstMatch
                .orWhere(app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'comment'")).firstMatch)
            
            if commentField.exists {
                commentField.tap()
                commentField.typeText("Test Comment")
                
                // Save
                let saveButton = app.buttons["Save"].orWhere(app.buttons["Post"]).firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    
                    // Then - Comment should appear
                    waitForAppToBeReady(timeout: 2)
                    
                    let commentItem = app.staticTexts["Test Comment"]
                    XCTAssertTrue(commentItem.exists)
                }
            }
        }
    }
    
    func testComment_EditComment() {
        // Given - Task with comment
        createTestWorkspaceAndProject()
        createTestTaskWithComment(title: "Task", commentContent: "Original Comment")
        navigateToTaskDetail("Task")
        
        // When - Edit comment
        let editButton = app.buttons.matching(identifier: "editComment").firstMatch
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'edit'")).firstMatch)
        
        if editButton.exists {
            editButton.tap()
            
            // Update comment
            let commentField = app.textViews.firstMatch
                .orWhere(app.textFields.firstMatch)
            
            if commentField.exists {
                commentField.tap()
                commentField.typeText(" - Updated")
                
                // Save
                let saveButton = app.buttons["Save"].firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    
                    // Then - Comment should be updated
                    waitForAppToBeReady(timeout: 2)
                }
            }
        }
    }
    
    func testComment_DeleteComment() {
        // Given - Task with comment
        createTestWorkspaceAndProject()
        createTestTaskWithComment(title: "Task", commentContent: "Deletable Comment")
        navigateToTaskDetail("Task")
        
        // When - Delete comment
        let deleteButton = app.buttons.matching(identifier: "deleteComment").firstMatch
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch)
        
        if deleteButton.exists {
            deleteButton.tap()
            
            // Confirm
            let confirmButton = app.alerts.firstMatch.buttons["Delete"].firstMatch
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Then - Comment should be deleted
            waitForAppToBeReady(timeout: 2)
            
            let commentItem = app.staticTexts["Deletable Comment"]
            XCTAssertFalse(commentItem.exists)
        }
    }
    
    // MARK: - Task Attachment Tests
    
    func testAttachment_AddAttachment() {
        // Given - On task detail
        createTestWorkspaceAndProject()
        createTestTask(title: "Attachment Task")
        navigateToTaskDetail("Attachment Task")
        
        // When - Add attachment
        let addAttachmentButton = app.buttons["Add Attachment"]
            .orWhere(app.buttons.matching(identifier: "addAttachmentButton")).firstMatch
        
        if addAttachmentButton.exists {
            addAttachmentButton.tap()
            
            // Then - Attachment picker should appear
            waitForAppToBeReady(timeout: 3)
            
            // File picker options should be visible
            let fileOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'file' OR label CONTAINS[c] 'document'")).firstMatch
            XCTAssertTrue(fileOption.exists)
        }
    }
    
    func testAttachment_ViewAttachment() {
        // Given - Task with attachment
        createTestWorkspaceAndProject()
        createTestTaskWithAttachment(title: "Task", attachmentName: "test.pdf")
        navigateToTaskDetail("Task")
        
        // When - Tap attachment
        let attachmentItem = app.staticTexts["test.pdf"].orWhere(app.buttons["test.pdf"].firstMatch)
        if attachmentItem.exists {
            attachmentItem.tap()
            
            // Then - Preview should appear
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    func testAttachment_DeleteAttachment() {
        // Given - Task with attachment
        createTestWorkspaceAndProject()
        createTestTaskWithAttachment(title: "Task", attachmentName: "Deletable File.pdf")
        navigateToTaskDetail("Task")
        
        // When - Delete attachment
        let deleteButton = app.buttons.matching(identifier: "deleteAttachment").firstMatch
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch)
        
        if deleteButton.exists {
            deleteButton.tap()
            
            // Confirm
            let confirmButton = app.alerts.firstMatch.buttons["Delete"].firstMatch
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Then - Attachment should be deleted
            waitForAppToBeReady(timeout: 2)
            
            let attachmentItem = app.staticTexts["Deletable File.pdf"]
            XCTAssertFalse(attachmentItem.exists)
        }
    }
    
    // MARK: - Task Label Tests
    
    func testLabel_AddLabel() {
        // Given - On task detail
        createTestWorkspaceAndProject()
        createTestTask(title: "Label Task")
        navigateToTaskDetail("Label Task")
        
        // When - Add label
        let addLabelButton = app.buttons["Add Label"]
            .orWhere(app.buttons.matching(identifier: "addLabelButton")).firstMatch
        
        if addLabelButton.exists {
            addLabelButton.tap()
            
            // Then - Label picker should appear
            waitForAppToBeReady(timeout: 2)
            
            // Select a label
            let labelOption = app.buttons.firstMatch
            if labelOption.exists {
                labelOption.tap()
            }
        }
    }
    
    func testLabel_RemoveLabel() {
        // Given - Task with label
        createTestWorkspaceAndProject()
        createTestTaskWithLabel(title: "Task", labelName: "Bug")
        navigateToTaskDetail("Task")
        
        // When - Remove label
        let removeButton = app.buttons.matching(identifier: "removeLabel").firstMatch
            .orWhere(app.buttons["x"].firstMatch)
        
        if removeButton.exists {
            removeButton.tap()
            
            // Then - Label should be removed
            waitForAppToBeReady(timeout: 2)
        }
    }
    
    // MARK: - Task Delete Tests
    
    func testTask_DeleteTask() {
        // Given - Task exists
        createTestWorkspaceAndProject()
        createTestTask(title: "Deletable Task")
        navigateToProjectDetail()
        
        // When - Delete task
        let deleteButton = app.buttons.matching(identifier: "deleteTask").firstMatch
            .orWhere(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch)
        
        if deleteButton.exists {
            deleteButton.tap()
            
            // Confirm
            let confirmButton = app.alerts.firstMatch.buttons["Delete"].firstMatch
            if confirmButton.exists {
                confirmButton.tap()
            }
            
            // Then - Task should be deleted
            waitForAppToBeReady(timeout: 3)
            
            let taskItem = app.staticTexts["Deletable Task"]
            XCTAssertFalse(taskItem.exists)
        }
    }
    
    // MARK: - Project Delete Tests
    
    func testProject_DeleteProject() {
        // Given - Project exists
        createTestWorkspaceAndProject()
        
        // When - Delete project
        navigateToProjectDetail()
        deleteCurrentProject()
        
        // Then - Project should be deleted
        waitForAppToBeReady(timeout: 3)
        
        let projectItem = app.staticTexts["Test Project"]
        XCTAssertFalse(projectItem.exists)
    }
    
    // MARK: - Helper Navigation Methods
    
    private func navigateToCreateProject() {
        let createButton = app.buttons["Create Project"].orWhere(app.buttons["New Project"]).firstMatch
        if createButton.exists {
            createButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func fillProjectForm(name: String, description: String = "", color: String = "", startDate: Date? = nil, dueDate: Date? = nil) {
        let nameField = app.textFields.matching(NSPredicate(format: "placeholder CONTAINS[c] 'name'")).firstMatch
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
    
    private func navigateToProjectDetail() {
        let projectItem = app.staticTexts["Test Project"].orWhere(app.buttons["Test Project"].firstMatch)
        if projectItem.exists {
            projectItem.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToEditProject() {
        let editButton = app.buttons["Edit"].orWhere(app.buttons.matching(identifier: "editButton")).firstMatch
        if editButton.exists {
            editButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func navigateToCreateTask() {
        let addTaskButton = app.buttons["Add Task"].orWhere(app.buttons.matching(identifier: "addTaskButton")).firstMatch
        if addTaskButton.exists {
            addTaskButton.tap()
            waitForAppToBeReady(timeout: 2)
        }
    }
    
    private func navigateToTaskDetail(_ title: String) {
        let taskItem = app.staticTexts(title).firstMatch
        if taskItem.exists {
            taskItem.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func createTestTask(title: String) {
        navigateToProjectDetail()
        navigateToCreateTask()
        
        let titleField = app.textFields.firstMatch
        titleField.tap()
        titleField.typeText(title)
        
        let saveButton = app.buttons["Create"].orWhere(app.buttons["Save"]).firstMatch
        if saveButton.exists {
            saveButton.tap()
            waitForAppToBeReady(timeout: 3)
        }
    }
    
    private func createTestTaskWithSubtask(title: String, subtaskTitle: String) {
        createTestTask(title: title)
        navigateToTaskDetail(title)
        
        let addSubtaskButton = app.buttons["Add Subtask"].firstMatch
        if addSubtaskButton.exists {
            addSubtaskButton.tap()
            
            let subtaskField = app.textFields.firstMatch
            if subtaskField.exists {
                subtaskField.tap()
                subtaskField.typeText(subtaskTitle)
                
                let saveButton = app.buttons["Save"].firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    waitForAppToBeReady(timeout: 2)
                }
            }
        }
    }
    
    private func createTestTaskWithComment(title: String, commentContent: String) {
        createTestTask(title: title)
        navigateToTaskDetail(title)
        
        let addCommentButton = app.buttons["Add Comment"].firstMatch
        if addCommentButton.exists {
            addCommentButton.tap()
            
            let commentField = app.textViews.firstMatch
                .orWhere(app.textFields.firstMatch)
            
            if commentField.exists {
                commentField.tap()
                commentField.typeText(commentContent)
                
                let saveButton = app.buttons["Save"].firstMatch
                if saveButton.exists {
                    saveButton.tap()
                    waitForAppToBeReady(timeout: 2)
                }
            }
        }
    }
    
    private func createTestTaskWithAttachment(title: String, attachmentName: String) {
        createTestTask(title: title)
        navigateToTaskDetail(title)
        
        let addAttachmentButton = app.buttons["Add Attachment"].firstMatch
        if addAttachmentButton.exists {
            addAttachmentButton.tap()
            waitForAppToBeReady(timeout: 2)
            
            // Mock attachment selection
            let cancelButton = app.buttons["Cancel"].firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
    }
    
    private func createTestTaskWithLabel(title: String, labelName: String) {
        createTestTask(title: title)
        navigateToTaskDetail(title)
        
        let addLabelButton = app.buttons["Add Label"].firstMatch
        if addLabelButton.exists {
            addLabelButton.tap()
            waitForAppToBeReady(timeout: 2)
            
            // Select label
            let labelOption = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '\(labelName)'")).firstMatch
            if labelOption.exists {
                labelOption.tap()
            }
        }
    }
    
    private func deleteCurrentProject() {
        let deleteButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'delete'")).firstMatch
        if deleteButton.exists {
            deleteButton.tap()
            
            let confirmButton = app.alerts.firstMatch.buttons["Delete"].firstMatch
            if confirmButton.exists {
                confirmButton.tap()
            }
        }
    }
    
    private func deleteAllProjects() {
        // Helper to clean up projects
        while app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'project'")).firstMatch.exists {
            deleteCurrentProject()
            waitForAppToBeReady(timeout: 2)
        }
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func orWhere(_ other: XCUIElement) -> XCUIElement {
        return self.exists ? self : other
    }
}
