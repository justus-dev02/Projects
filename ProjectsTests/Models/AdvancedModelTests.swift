//
//  AdvancedModelTests.swift
//  ProjectsTests
//
//  Comprehensive Unit Tests for Advanced Models (Label, CustomField, TaskDependency, RecurringTask, TaskTemplate, SavedView, NotificationModel)
//

import XCTest
@testable import Projects

@MainActor
final class AdvancedModelTests: XCTestCase {
    
    // MARK: - Label Tests
    
    func testLabel_Initialization_WithDefaultValues() {
        // Given & When
        let label = Label(name: "Bug")
        
        // Then
        XCTAssertEqual(label.name, "Bug")
        XCTAssertEqual(label.color, "#2D5BFF")
        XCTAssertNil(label.icon)
        XCTAssertEqual(label.order, 0)
        XCTAssertNotNil(label.id)
        XCTAssertNotNil(label.createdAt)
    }
    
    func testLabel_Initialization_WithCustomValues() {
        // Given
        let name = "Feature"
        let color = "#00BA88"
        let icon = "star.fill"
        let order = 5
        
        // When
        let label = Label(
            name: name,
            color: color,
            icon: icon,
            order: order
        )
        
        // Then
        XCTAssertEqual(label.name, name)
        XCTAssertEqual(label.color, color)
        XCTAssertEqual(label.icon, icon)
        XCTAssertEqual(label.order, order)
    }
    
    func testLabel_DefaultLabels() {
        // When
        let labels = Label.defaultLabels()
        
        // Then
        XCTAssertEqual(labels.count, 8)
        XCTAssertEqual(labels[0].name, "Bug")
        XCTAssertEqual(labels[1].name, "Feature")
        XCTAssertEqual(labels[2].name, "Enhancement")
        XCTAssertEqual(labels[3].name, "Documentation")
        XCTAssertEqual(labels[4].name, "Testing")
        XCTAssertEqual(labels[5].name, "Design")
        XCTAssertEqual(labels[6].name, "Research")
        XCTAssertEqual(labels[7].name, "Meeting")
    }
    
    func testLabel_WorkspaceRelationship() {
        // Given
        let workspace = Workspace(name: "Test Workspace")
        let label = Label(name: "Bug")
        
        // When
        label.workspace = workspace
        
        // Then
        XCTAssertEqual(label.workspace, workspace)
    }
    
    func testLabel_TaskLabelsRelationship() {
        // Given
        let label = Label(name: "Bug")
        let taskLabel1 = TaskLabel()
        let taskLabel2 = TaskLabel()
        
        // When
        label.taskLabels = [taskLabel1, taskLabel2]
        
        // Then
        XCTAssertEqual(label.taskLabels?.count, 2)
    }
    
    // MARK: - CustomFieldDefinition Tests
    
    func testCustomFieldDefinition_Initialization_WithDefaultValues() {
        // Given & When
        let definition = CustomFieldDefinition(name: "Priority")
        
        // Then
        XCTAssertEqual(definition.name, "Priority")
        XCTAssertEqual(definition.fieldType, "text")
        XCTAssertNil(definition.options)
        XCTAssertNil(definition.defaultValue)
        XCTAssertFalse(definition.isRequired)
        XCTAssertEqual(definition.order, 0)
        XCTAssertNil(definition.color)
        XCTAssertNil(definition.icon)
        XCTAssertNotNil(definition.id)
        XCTAssertNotNil(definition.createdAt)
        XCTAssertNotNil(definition.updatedAt)
    }
    
    func testCustomFieldDefinition_Initialization_WithCustomValues() {
        // Given
        let name = "Story Points"
        let fieldType = "number"
        let options = "[\"1\", \"2\", \"3\", \"5\", \"8\"]"
        let defaultValue = "1"
        let isRequired = true
        let order = 5
        let color = "#45B7D1"
        let icon = "number"
        
        // When
        let definition = CustomFieldDefinition(
            name: name,
            fieldType: fieldType,
            options: options,
            defaultValue: defaultValue,
            isRequired: isRequired,
            order: order,
            color: color,
            icon: icon
        )
        
        // Then
        XCTAssertEqual(definition.name, name)
        XCTAssertEqual(definition.fieldType, fieldType)
        XCTAssertEqual(definition.options, options)
        XCTAssertEqual(definition.defaultValue, defaultValue)
        XCTAssertTrue(definition.isRequired)
        XCTAssertEqual(definition.order, order)
        XCTAssertEqual(definition.color, color)
        XCTAssertEqual(definition.icon, icon)
    }
    
    func testCustomFieldDefinition_FieldType_AllCases() {
        // Then
        XCTAssertEqual(CustomFieldDefinition.FieldType.allCases.count, 13)
        XCTAssertEqual(CustomFieldDefinition.FieldType.text.rawValue, "Text")
        XCTAssertEqual(CustomFieldDefinition.FieldType.number.rawValue, "Number")
        XCTAssertEqual(CustomFieldDefinition.FieldType.date.rawValue, "Date")
        XCTAssertEqual(CustomFieldDefinition.FieldType.dropdown.rawValue, "Dropdown")
        XCTAssertEqual(CustomFieldDefinition.FieldType.multiSelect.rawValue, "Multi-select")
        XCTAssertEqual(CustomFieldDefinition.FieldType.checkbox.rawValue, "Checkbox")
        XCTAssertEqual(CustomFieldDefinition.FieldType.url.rawValue, "URL")
        XCTAssertEqual(CustomFieldDefinition.FieldType.email.rawValue, "Email")
        XCTAssertEqual(CustomFieldDefinition.FieldType.phone.rawValue, "Phone")
        XCTAssertEqual(CustomFieldDefinition.FieldType.currency.rawValue, "Currency")
        XCTAssertEqual(CustomFieldDefinition.FieldType.percent.rawValue, "Percentage")
        XCTAssertEqual(CustomFieldDefinition.FieldType.rating.rawValue, "Rating")
        XCTAssertEqual(CustomFieldDefinition.FieldType.person.rawValue, "Person")
    }
    
    func testCustomFieldDefinition_FieldType_IsMultiValue() {
        // Then
        XCTAssertTrue(CustomFieldDefinition.FieldType.multiSelect.isMultiValue)
        XCTAssertFalse(CustomFieldDefinition.FieldType.text.isMultiValue)
        XCTAssertFalse(CustomFieldDefinition.FieldType.number.isMultiValue)
    }
    
    func testCustomFieldDefinition_FieldType_RequiresOptions() {
        // Then
        XCTAssertTrue(CustomFieldDefinition.FieldType.dropdown.requiresOptions)
        XCTAssertTrue(CustomFieldDefinition.FieldType.multiSelect.requiresOptions)
        XCTAssertFalse(CustomFieldDefinition.FieldType.text.requiresOptions)
        XCTAssertFalse(CustomFieldDefinition.FieldType.number.requiresOptions)
    }
    
    func testCustomFieldDefinition_ParsedOptions() {
        // Given
        let options = "[\"Option 1\", \"Option 2\", \"Option 3\"]"
        let definition = CustomFieldDefinition(
            name: "Priority",
            fieldType: "dropdown",
            options: options
        )
        
        // When
        let parsed = definition.parsedOptions
        
        // Then
        XCTAssertEqual(parsed?.count, 3)
        XCTAssertEqual(parsed?[0], "Option 1")
        XCTAssertEqual(parsed?[1], "Option 2")
        XCTAssertEqual(parsed?[2], "Option 3")
    }
    
    func testCustomFieldDefinition_ParsedOptions_WhenNil() {
        // Given
        let definition = CustomFieldDefinition(name: "Priority")
        
        // When
        let parsed = definition.parsedOptions
        
        // Then
        XCTAssertNil(parsed)
    }
    
    func testCustomFieldDefinition_ProjectRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let definition = CustomFieldDefinition(name: "Priority")
        
        // When
        definition.project = project
        
        // Then
        XCTAssertEqual(definition.project, project)
    }
    
    func testCustomFieldDefinition_ValuesRelationship() {
        // Given
        let definition = CustomFieldDefinition(name: "Priority")
        let value1 = CustomFieldValue()
        let value2 = CustomFieldValue()
        
        // When
        definition.values = [value1, value2]
        
        // Then
        XCTAssertEqual(definition.values?.count, 2)
    }
    
    // MARK: - CustomFieldValue Tests
    
    func testCustomFieldValue_Initialization_WithDefaultValues() {
        // Given & When
        let value = CustomFieldValue()
        
        // Then
        XCTAssertNotNil(value.id)
        XCTAssertEqual(value.value, "")
        XCTAssertNotNil(value.updatedAt)
    }
    
    func testCustomFieldValue_Initialization_WithCustomValues() {
        // Given
        let value = "Test Value"
        let updatedAt = Date().addingTimeInterval(-3600)
        
        // When
        let fieldValue = CustomFieldValue(
            value: value,
            updatedAt: updatedAt
        )
        
        // Then
        XCTAssertEqual(fieldValue.value, value)
        XCTAssertEqual(fieldValue.updatedAt, updatedAt)
    }
    
    func testCustomFieldValue_TextValue() {
        // Given
        let fieldValue = CustomFieldValue(value: "Test Text")
        
        // Then
        XCTAssertEqual(fieldValue.textValue, "Test Text")
    }
    
    func testCustomFieldValue_TextValue_WhenEmpty() {
        // Given
        let fieldValue = CustomFieldValue(value: "")
        
        // Then
        XCTAssertNil(fieldValue.textValue)
    }
    
    func testCustomFieldValue_NumberValue_Valid() {
        // Given
        let fieldValue = CustomFieldValue(value: "42.5")
        
        // Then
        XCTAssertEqual(fieldValue.numberValue, 42.5)
    }
    
    func testCustomFieldValue_NumberValue_Invalid() {
        // Given
        let fieldValue = CustomFieldValue(value: "not a number")
        
        // Then
        XCTAssertNil(fieldValue.numberValue)
    }
    
    func testCustomFieldValue_NumberValue_WhenEmpty() {
        // Given
        let fieldValue = CustomFieldValue(value: "")
        
        // Then
        XCTAssertNil(fieldValue.numberValue)
    }
    
    func testCustomFieldValue_BoolValue_True() {
        // Given
        let fieldValue = CustomFieldValue(value: "true")
        
        // Then
        XCTAssertTrue(fieldValue.boolValue == true)
    }
    
    func testCustomFieldValue_BoolValue_False() {
        // Given
        let fieldValue = CustomFieldValue(value: "false")
        
        // Then
        XCTAssertTrue(fieldValue.boolValue == false)
    }
    
    func testCustomFieldValue_BoolValue_One() {
        // Given
        let fieldValue = CustomFieldValue(value: "1")
        
        // Then
        XCTAssertTrue(fieldValue.boolValue == true)
    }
    
    func testCustomFieldValue_ArrayValue() {
        // Given
        let arrayValue = "[\"Option 1\", \"Option 2\", \"Option 3\"]"
        let fieldValue = CustomFieldValue(value: arrayValue)
        
        // When
        let parsed = fieldValue.arrayValue
        
        // Then
        XCTAssertEqual(parsed?.count, 3)
        XCTAssertEqual(parsed?[0], "Option 1")
        XCTAssertEqual(parsed?[1], "Option 2")
        XCTAssertEqual(parsed?[2], "Option 3")
    }
    
    func testCustomFieldValue_ArrayValue_Invalid() {
        // Given
        let fieldValue = CustomFieldValue(value: "not json")
        
        // Then
        XCTAssertNil(fieldValue.arrayValue)
    }
    
    func testCustomFieldValue_URLValue_Valid() {
        // Given
        let fieldValue = CustomFieldValue(value: "https://example.com")
        
        // Then
        XCTAssertEqual(fieldValue.urlValue, URL(string: "https://example.com"))
    }
    
    func testCustomFieldValue_URLValue_Invalid() {
        // Given
        let fieldValue = CustomFieldValue(value: "not a url")
        
        // Then
        XCTAssertNil(fieldValue.urlValue)
    }
    
    func testCustomFieldValue_DefinitionRelationship() {
        // Given
        let definition = CustomFieldDefinition(name: "Priority")
        let fieldValue = CustomFieldValue()
        
        // When
        fieldValue.definition = definition
        
        // Then
        XCTAssertEqual(fieldValue.definition, definition)
    }
    
    func testCustomFieldValue_TaskRelationship() {
        // Given
        let task = Task(title: "Test Task")
        let fieldValue = CustomFieldValue()
        
        // When
        fieldValue.task = task
        
        // Then
        XCTAssertEqual(fieldValue.task, task)
    }
    
    // MARK: - TaskDependency Tests
    
    func testTaskDependency_Initialization_WithDefaultValues() {
        // Given & When
        let dependency = TaskDependency()
        
        // Then
        XCTAssertNotNil(dependency.id)
        XCTAssertEqual(dependency.dependencyType, "finishToStart")
        XCTAssertEqual(dependency.lagDays, 0)
        XCTAssertNotNil(dependency.createdAt)
    }
    
    func testTaskDependency_Initialization_WithCustomValues() {
        // Given
        let dependencyType = "startToStart"
        let lagDays = 3
        
        // When
        let dependency = TaskDependency(
            dependencyType: dependencyType,
            lagDays: lagDays
        )
        
        // Then
        XCTAssertEqual(dependency.dependencyType, dependencyType)
        XCTAssertEqual(dependency.lagDays, lagDays)
    }
    
    func testTaskDependency_DependencyType_AllCases() {
        // Then
        XCTAssertEqual(TaskDependency.DependencyType.allCases.count, 4)
        XCTAssertEqual(TaskDependency.DependencyType.finishToStart, .finishToStart)
        XCTAssertEqual(TaskDependency.DependencyType.startToStart, .startToStart)
        XCTAssertEqual(TaskDependency.DependencyType.finishToFinish, .finishToFinish)
        XCTAssertEqual(TaskDependency.DependencyType.startToFinish, .startToFinish)
    }
    
    func testTaskDependency_DependencyType_Description() {
        // Then
        XCTAssertEqual(TaskDependency.DependencyType.finishToStart.description, "Predecessor must finish before successor can start")
        XCTAssertEqual(TaskDependency.DependencyType.startToStart.description, "Predecessor must start before successor can start")
        XCTAssertEqual(TaskDependency.DependencyType.finishToFinish.description, "Predecessor must finish before successor can finish")
        XCTAssertEqual(TaskDependency.DependencyType.startToFinish.description, "Predecessor must start before successor can finish")
    }
    
    func testTaskDependency_IsBlocking_WhenFinishToStartAndPredecessorNotCompleted() {
        // Given
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "todo"
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        
        // Then
        XCTAssertTrue(dependency.isBlocking)
    }
    
    func testTaskDependency_IsBlocking_WhenFinishToStartAndPredecessorCompleted() {
        // Given
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "done"
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        
        // Then
        XCTAssertFalse(dependency.isBlocking)
    }
    
    func testTaskDependency_IsBlocking_WhenNotFinishToStart() {
        // Given
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "todo"
        let dependency = TaskDependency(dependencyType: "startToStart")
        dependency.predecessor = predecessor
        
        // Then
        XCTAssertFalse(dependency.isBlocking)
    }
    
    func testTaskDependency_CanStartSuccessor_FinishToStart() {
        // Given
        let predecessor = Task(title: "Predecessor")
        predecessor.status = "done"
        let dependency = TaskDependency(dependencyType: "finishToStart")
        dependency.predecessor = predecessor
        
        // Then
        XCTAssertTrue(dependency.canStartSuccessor)
    }
    
    func testTaskDependency_CanStartSuccessor_StartToStart() {
        // Given
        let predecessor = Task(title: "Predecessor")
        let dependency = TaskDependency(dependencyType: "startToStart")
        dependency.predecessor = predecessor
        
        // Then
        XCTAssertTrue(dependency.canStartSuccessor)
    }
    
    func testTaskDependency_PredecessorRelationship() {
        // Given
        let predecessor = Task(title: "Predecessor")
        let dependency = TaskDependency()
        
        // When
        dependency.predecessor = predecessor
        
        // Then
        XCTAssertEqual(dependency.predecessor, predecessor)
    }
    
    func testTaskDependency_SuccessorRelationship() {
        // Given
        let successor = Task(title: "Successor")
        let dependency = TaskDependency()
        
        // When
        dependency.successor = successor
        
        // Then
        XCTAssertEqual(dependency.successor, successor)
    }
    
    // MARK: - RecurringTask Tests
    
    func testRecurringTask_Initialization_WithDefaultValues() {
        // Given & When
        let recurring = RecurringTask()
        
        // Then
        XCTAssertNotNil(recurring.id)
        XCTAssertEqual(recurring.frequency, "weekly")
        XCTAssertEqual(recurring.interval, 1)
        XCTAssertNil(recurring.daysOfWeek)
        XCTAssertNil(recurring.dayOfMonth)
        XCTAssertNil(recurring.monthOfYear)
        XCTAssertNil(recurring.endDate)
        XCTAssertNil(recurring.occurrences)
        XCTAssertEqual(recurring.createAheadDays, 1)
        XCTAssertTrue(recurring.isParentTask)
        XCTAssertNotNil(recurring.createdAt)
        XCTAssertNotNil(recurring.updatedAt)
    }
    
    func testRecurringTask_Initialization_WithCustomValues() {
        // Given
        let frequency = "daily"
        let interval = 2
        let daysOfWeek = "1,3,5"
        let dayOfMonth = 15
        let monthOfYear = 6
        let endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        let occurrences = 10
        let createAheadDays = 3
        
        // When
        let recurring = RecurringTask(
            frequency: frequency,
            interval: interval,
            daysOfWeek: daysOfWeek,
            dayOfMonth: dayOfMonth,
            monthOfYear: monthOfYear,
            endDate: endDate,
            occurrences: occurrences,
            createAheadDays: createAheadDays
        )
        
        // Then
        XCTAssertEqual(recurring.frequency, frequency)
        XCTAssertEqual(recurring.interval, interval)
        XCTAssertEqual(recurring.daysOfWeek, daysOfWeek)
        XCTAssertEqual(recurring.dayOfMonth, dayOfMonth)
        XCTAssertEqual(recurring.monthOfYear, monthOfYear)
        XCTAssertEqual(recurring.endDate, endDate)
        XCTAssertEqual(recurring.occurrences, occurrences)
        XCTAssertEqual(recurring.createAheadDays, createAheadDays)
    }
    
    func testRecurringTask_Frequency_AllCases() {
        // Then
        XCTAssertEqual(RecurringTask.Frequency.allCases.count, 6)
        XCTAssertEqual(RecurringTask.Frequency.daily, .daily)
        XCTAssertEqual(RecurringTask.Frequency.weekly, .weekly)
        XCTAssertEqual(RecurringTask.Frequency.biweekly, .biweekly)
        XCTAssertEqual(RecurringTask.Frequency.monthly, .monthly)
        XCTAssertEqual(RecurringTask.Frequency.yearly, .yearly)
        XCTAssertEqual(RecurringTask.Frequency.custom, .custom)
    }
    
    func testRecurringTask_DaysOfWeek_AllCases() {
        // Then
        XCTAssertEqual(RecurringTask.DaysOfWeek.allCases.count, 7)
        XCTAssertEqual(RecurringTask.DaysOfWeek.sunday.shortName, "Sun")
        XCTAssertEqual(RecurringTask.DaysOfWeek.monday.shortName, "Mon")
        XCTAssertEqual(RecurringTask.DaysOfWeek.tuesday.shortName, "Tue")
        XCTAssertEqual(RecurringTask.DaysOfWeek.wednesday.shortName, "Wed")
        XCTAssertEqual(RecurringTask.DaysOfWeek.thursday.shortName, "Thu")
        XCTAssertEqual(RecurringTask.DaysOfWeek.friday.shortName, "Fri")
        XCTAssertEqual(RecurringTask.DaysOfWeek.saturday.shortName, "Sat")
    }
    
    func testRecurringTask_FrequencyDescription_Daily() {
        // Given
        let recurring = RecurringTask(frequency: "daily", interval: 1)
        
        // Then
        XCTAssertEqual(recurring.frequencyDescription, "Daily")
    }
    
    func testRecurringTask_FrequencyDescription_DailyInterval() {
        // Given
        let recurring = RecurringTask(frequency: "daily", interval: 3)
        
        // Then
        XCTAssertEqual(recurring.frequencyDescription, "Every 3 days")
    }
    
    func testRecurringTask_FrequencyDescription_Weekly() {
        // Given
        let recurring = RecurringTask(frequency: "weekly", interval: 1)
        
        // Then
        XCTAssertEqual(recurring.frequencyDescription, "Weekly")
    }
    
    func testRecurringTask_FrequencyDescription_Monthly() {
        // Given
        let recurring = RecurringTask(frequency: "monthly", dayOfMonth: 15)
        
        // Then
        XCTAssertEqual(recurring.frequencyDescription, "On day 15 of each month")
    }
    
    func testRecurringTask_CalculateNextDate_Daily() {
        // Given
        let recurring = RecurringTask(frequency: "daily", interval: 1)
        let baseDate = Date()
        
        // When
        let nextDate = recurring.calculateNextDate(after: baseDate)
        
        // Then
        let expectedDate = Calendar.current.date(byAdding: .day, value: 1, to: baseDate)!
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: nextDate),
                      Calendar.current.dateComponents([.year, .month, .day], from: expectedDate))
    }
    
    func testRecurringTask_CalculateNextDate_Weekly() {
        // Given
        let recurring = RecurringTask(frequency: "weekly", interval: 1)
        let baseDate = Date()
        
        // When
        let nextDate = recurring.calculateNextDate(after: baseDate)
        
        // Then
        let expectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: baseDate)!
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: nextDate),
                      Calendar.current.dateComponents([.year, .month, .day], from: expectedDate))
    }
    
    func testRecurringTask_CalculateNextDate_Monthly() {
        // Given
        let recurring = RecurringTask(frequency: "monthly", interval: 1)
        let baseDate = Date()
        
        // When
        let nextDate = recurring.calculateNextDate(after: baseDate)
        
        // Then
        let expectedDate = Calendar.current.date(byAdding: .month, value: 1, to: baseDate)!
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: nextDate),
                      Calendar.current.dateComponents([.year, .month, .day], from: expectedDate))
    }
    
    func testRecurringTask_ParentTaskRelationship() {
        // Given
        let task = Task(title: "Recurring Task")
        let recurring = RecurringTask()
        
        // When
        recurring.parentTask = task
        
        // Then
        XCTAssertEqual(recurring.parentTask, task)
    }
    
    func testRecurringTask_InstancesRelationship() {
        // Given
        let recurring = RecurringTask()
        let instance1 = Task(title: "Instance 1")
        let instance2 = Task(title: "Instance 2")
        
        // When
        recurring.instances = [instance1, instance2]
        
        // Then
        XCTAssertEqual(recurring.instances?.count, 2)
    }
    
    func testRecurringTask_ProjectRelationship() {
        // Given
        let project = Project(name: "Test Project")
        let recurring = RecurringTask()
        
        // When
        recurring.project = project
        
        // Then
        XCTAssertEqual(recurring.project, project)
    }
}
