import Foundation
import SwiftData
import Testing
import ProjectsCore
@testable import ProjectsData

@Suite("Blocked tasks")
struct BlockedTaskTests {
    private func makeBlockedTask() throws -> (TestStack, Project, blocker: TaskItem, task: TaskItem) {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let blocker = try stack.tasks.create(TaskDraft(title: "Blocker"), in: project)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.addDependency(task, blockedBy: blocker)
        return (stack, project, blocker, task)
    }

    @Test(arguments: [TaskStatus.inProgress, .review, .done])
    func aBlockedTaskCannotLeaveToDo(status: TaskStatus) throws {
        let (stack, _, _, task) = try makeBlockedTask()

        #expect(throws: ProjectsError.taskBlocked(taskTitle: "Task", blockerTitles: ["Blocker"])) {
            try stack.tasks.setStatus(task, to: status)
        }
        #expect(task.status == .todo)
        #expect(task.column?.status == .todo)
    }

    @Test func movingABlockedTaskToAnotherColumnIsRejected() throws {
        let (stack, project, _, task) = try makeBlockedTask()
        let inProgress = stack.column(project, .inProgress)

        #expect(throws: ProjectsError.self) {
            try stack.tasks.move(task, to: inProgress, at: 0)
        }
        #expect(task.column?.status == .todo)
        #expect(inProgress.sortedTasks.isEmpty)
    }

    @Test func completingABlockedTaskIsRejected() throws {
        let (stack, _, _, task) = try makeBlockedTask()
        #expect(throws: ProjectsError.self) {
            try stack.tasks.toggleCompletion(task)
        }
        #expect(!task.isCompleted)
    }

    @Test func bulkStatusChangeIsAllOrNothing() throws {
        let (stack, project, _, task) = try makeBlockedTask()
        let free = try stack.tasks.create(TaskDraft(title: "Free"), in: project)

        #expect(throws: ProjectsError.self) {
            try stack.tasks.setStatus([free, task], to: .done)
        }
        #expect(free.status == .todo, "Nothing changes when one task is blocked")
    }

    @Test func reorderingWithinToDoStaysPossible() throws {
        let (stack, project, _, task) = try makeBlockedTask()
        try stack.tasks.move(task, to: stack.column(project, .todo), at: 0)
        #expect(stack.column(project, .todo).sortedTasks.first?.id == task.id)
    }

    @Test func finishingTheBlockerUnblocksTheTask() throws {
        let (stack, _, blocker, task) = try makeBlockedTask()
        try stack.tasks.setStatus(blocker, to: .done)

        #expect(!task.isBlocked)
        try stack.tasks.setStatus(task, to: .inProgress)
        #expect(task.status == .inProgress)
    }

    @Test func aTaskThatBecomesBlockedCanGoBackToToDo() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let blocker = try stack.tasks.create(TaskDraft(title: "Blocker"), in: project)
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.setStatus(task, to: .inProgress)
        try stack.tasks.addDependency(task, blockedBy: blocker)

        #expect(throws: ProjectsError.self) { try stack.tasks.setStatus(task, to: .review) }
        try stack.tasks.setStatus(task, to: .todo)
        #expect(task.status == .todo)
    }

    @Test func dependencyIsStoredOnBothSides() throws {
        let (stack, _, blocker, task) = try makeBlockedTask()
        defer { withExtendedLifetime(stack) {} }
        #expect(task.blockers.map(\.id) == [blocker.id])
        #expect(blocker.dependents.map(\.id) == [task.id])
        #expect(task.openBlockers.map(\.id) == [blocker.id])
        #expect(blocker.blockers.isEmpty)
    }

    @Test func theErrorNamesAllOpenBlockers() {
        let error = ProjectsError.taskBlocked(taskTitle: "Submit", blockerTitles: ["A", "B"])
        let description = error.errorDescription ?? ""
        #expect(description.contains("Submit"))
        #expect(description.contains("A") && description.contains("B"))
        #expect(error.recoverySuggestion != nil)
    }
}

@Suite("People and questions")
struct PeopleAndQuestionTests {
    @Test func peopleAreTrimmedAndDeduplicated() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task", involvedPeople: [" Anna ", "anna", "Jonas"]), in: project)
        #expect(task.involvedPeople == ["Anna", "Jonas"])

        try stack.tasks.addPerson(named: "Mia", to: task)
        try stack.tasks.addPerson(named: "JONAS", to: task)
        #expect(task.involvedPeople == ["Anna", "Jonas", "Mia"])

        try stack.tasks.removePerson(named: "Jonas", from: task)
        #expect(task.involvedPeople == ["Anna", "Mia"])
    }

    @Test func anEmptyNameIsRejected() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        #expect(throws: ProjectsError.emptyField(.personName)) {
            try stack.tasks.addPerson(named: "  ", to: task)
        }
        #expect(task.involvedPeople.isEmpty)
    }

    @Test func updatingADraftReplacesThePeople() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task", involvedPeople: ["Anna"]), in: project)
        var draft = TaskDraft(task: task)
        draft.involvedPeople = ["Mia"]
        try stack.tasks.update(task, with: draft)
        #expect(task.involvedPeople == ["Mia"])
    }

    @Test func openQuestionsAreCounted() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let first = try stack.tasks.addQuestion(to: task, text: "Budget?")
        try stack.tasks.addQuestion(to: task, text: "Deadline?")
        #expect(task.openQuestionCount == 2)
        #expect(task.sortedQuestions.map(\.text) == ["Budget?", "Deadline?"])

        try stack.tasks.toggleQuestion(first)
        #expect(task.openQuestionCount == 1)
        #expect(first.answeredAt == stack.now)

        try stack.tasks.toggleQuestion(first)
        #expect(first.answeredAt == nil)

        try stack.tasks.deleteQuestion(first)
        #expect(task.openQuestionCount == 1)
        #expect(try stack.count(TaskQuestion.self) == 1)
    }

    @Test func deletingATaskDeletesItsQuestions() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.addQuestion(to: task, text: "Budget?")
        try stack.tasks.delete(task)
        #expect(try stack.count(TaskQuestion.self) == 0)
    }

    @Test func recurringTasksKeepTheirPeople() throws {
        let stack = try TestStack()
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(
            TaskDraft(title: "Sync", dueDate: stack.date(dayOffset: 0), recurrence: RecurrenceRule(frequency: .weekly), involvedPeople: ["Anna"]),
            in: project
        )
        let next = try #require(try stack.tasks.toggleCompletion(task))
        #expect(next.involvedPeople == ["Anna"])
    }
}

private extension Installation {
    /// An installation that has existed forever, so only the author decides about "unread".
    static func device(_ id: String) -> Installation {
        Installation(id: id, installedAt: .distantPast)
    }
}

@Suite("Unread comments")
struct UnreadCommentTests {
    private func makeStack(deviceID: String) throws -> TestStack {
        try TestStack(deviceID: deviceID)
    }

    @Test func ownCommentsAreNeverUnread() throws {
        let stack = try makeStack(deviceID: "mac")
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let comment = try stack.tasks.addComment(to: task, text: "Hello")

        #expect(comment.authorDeviceID == "mac")
        #expect(task.hasComments)
        #expect(!task.hasUnreadComments(in: .device("mac")))
        #expect(task.hasUnreadComments(in: .device("iphone")), "The same comment is new on another device")
    }

    @Test func viewingATaskMarksCommentsFromOtherDevicesAsRead() throws {
        let stack = try makeStack(deviceID: "mac")
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let comment = try stack.tasks.addComment(to: task, text: "Hello")
        comment.authorDeviceID = "iphone"
        let updatedAt = task.updatedAt

        #expect(task.hasUnreadComments(in: .device("mac")))
        try stack.tasks.markCommentsRead(of: task)

        #expect(!task.hasUnreadComments(in: .device("mac")))
        #expect(comment.isRead)
        #expect(task.updatedAt == updatedAt, "Reading is not an edit")
    }

    @Test("Comments written before this installation existed are read, e.g. after a reinstall")
    func commentsOlderThanTheInstallationAreRead() throws {
        let stack = try makeStack(deviceID: "old-mac")
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.addComment(to: task, text: "Written before the reinstall")

        let reinstalled = Installation(id: "new-mac", installedAt: stack.now.addingTimeInterval(60))
        #expect(!task.hasUnreadComments(in: reinstalled))

        let installedEarlier = Installation(id: "new-mac", installedAt: stack.now.addingTimeInterval(-60))
        #expect(task.hasUnreadComments(in: installedEarlier), "Comments written elsewhere after installing are new")
    }

    @Test func theUnknownInstallationNeverSeesUnreadComments() throws {
        let stack = try makeStack(deviceID: "mac")
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        try stack.tasks.addComment(to: task, text: "Hello")
        #expect(!task.hasUnreadComments(in: .unknown))
    }

    @Test func commentsWithoutAuthorAreRead() throws {
        let stack = try makeStack(deviceID: "mac")
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task"), in: project)
        let comment = try stack.tasks.addComment(to: task, text: "From version 1")
        comment.authorDeviceID = ""
        #expect(!task.hasUnreadComments(in: .device("mac")))
    }

    @Test func sampleDataContainsAnUnreadComment() throws {
        let stack = try makeStack(deviceID: "mac")
        try DemoDataSeeder(environment: stack.environment).seed()
        let tasks = try stack.context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.contains { $0.hasUnreadComments(in: .device("mac")) })
        #expect(tasks.contains { $0.openQuestionCount > 0 })
        #expect(tasks.contains { !$0.involvedPeople.isEmpty })
        #expect(tasks.contains { $0.isBlocked })
    }
}

@Suite("Backup and undo of the new task details")
struct NewDetailsRoundTripTests {
    private func makeTask(in stack: TestStack) throws -> TaskItem {
        let (_, project) = try stack.makeProject()
        let task = try stack.tasks.create(TaskDraft(title: "Task", involvedPeople: ["Anna"]), in: project)
        let question = try stack.tasks.addQuestion(to: task, text: "Budget?")
        try stack.tasks.toggleQuestion(question)
        try stack.tasks.addQuestion(to: task, text: "Deadline?")
        let comment = try stack.tasks.addComment(to: task, text: "Hi")
        comment.authorDeviceID = "iphone"
        return task
    }

    @Test func undoDeleteRestoresPeopleQuestionsAndUnreadState() throws {
        let stack = try TestStack(deviceID: "mac")
        let task = try makeTask(in: stack)
        let id = task.id

        let deleted = try stack.tasks.deleteUndoably([task])
        try stack.tasks.restore(deleted)

        let restored = try #require(try stack.tasks.task(id: id))
        #expect(restored.involvedPeople == ["Anna"])
        #expect(restored.sortedQuestions.map(\.text) == ["Budget?", "Deadline?"])
        #expect(restored.openQuestionCount == 1)
        #expect(restored.hasUnreadComments(in: .device("mac")))
    }

    @Test func backupRoundTripKeepsPeopleAndQuestions() throws {
        let stack = try TestStack(deviceID: "mac")
        _ = try makeTask(in: stack)
        let data = try stack.backup.exportJSON()

        let target = try TestStack(deviceID: "mac")
        try target.backup.importJSON(data, mode: .replaceAll)
        let task = try #require(try target.context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(task.involvedPeople == ["Anna"])
        #expect(task.openQuestionCount == 1)
        #expect(task.hasUnreadComments(in: .device("mac")))
    }

    @Test func backupsWithoutTheNewFieldsStillDecode() throws {
        let json = """
        {"formatVersion":1,"exportedAt":"2026-01-01T00:00:00Z","workspaces":[]}
        """
        let document = try BackupDocument.decode(from: Data(json.utf8))
        #expect(document.workspaces.isEmpty)

        let comment = try BackupDocument.makeDecoder().decode(
            BackupDocument.CommentRecord.self,
            from: Data(#"{"id":"\#(UUID().uuidString)","text":"x","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z"}"#.utf8)
        )
        #expect(comment.authorDeviceID == nil)
    }
}

@Suite("Migration")
struct MigrationTests {
    @Test("A version 1 store opens with version 2 and keeps its data")
    func migrateV1Store() throws {
        let directory = URL.temporaryDirectory.appending(path: "ProjectsMigration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: PersistenceController.storeFileName)

        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(container)
            let task = SchemaV1.TaskItem(title: "Old task")
            context.insert(task)
            let comment = SchemaV1.TaskComment(text: "Old comment")
            context.insert(comment)
            comment.task = task
            try context.save()
        }

        let migrated = try PersistenceController.makeContainer(PersistenceConfiguration(storage: .file(url)))
        let task = try #require(try migrated.mainContext.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(task.title == "Old task")
        #expect(task.involvedPeople.isEmpty)
        #expect(task.openQuestionCount == 0)
        #expect(task.sortedComments.first?.text == "Old comment")
        #expect(!task.hasUnreadComments(in: .device("any-device")), "Comments from version 1 count as read")
    }
}
