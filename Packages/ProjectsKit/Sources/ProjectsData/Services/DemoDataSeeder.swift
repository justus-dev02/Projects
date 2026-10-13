import Foundation
import SwiftData
import ProjectsCore

#if DEBUG
/// Creates realistic sample data in the current language – a test fixture, not a feature.
///
/// The app always starts empty. This seeder only exists in debug builds, for tests, UI tests and
/// screenshots (launch argument `-seed-demo-data`); release builds do not contain it. All dates are
/// relative to the injected `now`, so the result is deterministic for tests.
public final class DemoDataSeeder {
    private let environment: ServiceEnvironment
    private let workspaces: WorkspaceService
    private let projects: ProjectService
    private let tasks: TaskService
    private let templates: TemplateService

    public init(environment: ServiceEnvironment) {
        self.environment = environment
        workspaces = WorkspaceService(environment: environment)
        projects = ProjectService(environment: environment)
        tasks = TaskService(environment: environment)
        templates = TemplateService(environment: environment, taskService: tasks)
    }

    /// `true` when the store contains no workspace yet.
    public func isStoreEmpty() throws -> Bool {
        try environment.count(FetchDescriptor<Workspace>()) == 0
    }

    public func seedIfEmpty() throws {
        guard try isStoreEmpty() else { return }
        try seed()
    }

    // swiftlint:disable:next function_body_length
    public func seed() throws {
        let calendar = environment.calendar
        let now = environment.now()
        func day(_ offset: Int, hour: Int = 17) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) ?? now
            return calendar.date(byAdding: .hour, value: hour, to: base) ?? base
        }

        // Work
        let work = try workspaces.create(
            name: String(localized: "Work", bundle: .module, comment: "Sample workspace"),
            details: String(localized: "Projects for the team at the office.", bundle: .module, comment: "Sample workspace description"),
            colorHex: ColorPalette.indigo,
            symbolName: "briefcase"
        )
        let labels = Dictionary(uniqueKeysWithValues: work.sortedLabels.map { ($0.order, $0.id) })
        let bugLabel = labels[0].map { Set([$0]) } ?? []
        let featureLabel = labels[1].map { Set([$0]) } ?? []

        let app = try projects.create(ProjectDraft(
            name: String(localized: "iOS App Launch", bundle: .module, comment: "Sample project"),
            details: String(localized: "Everything needed for version 1.0 in the App Store.", bundle: .module, comment: "Sample project description"),
            colorHex: ColorPalette.blue,
            symbolName: "laptopcomputer",
            startDate: day(-14),
            dueDate: day(30)
        ), in: work)

        let design = try tasks.create(TaskDraft(
            title: String(localized: "Finalize app icon", bundle: .module, comment: "Sample task"),
            priority: .high,
            startDate: day(-10),
            dueDate: day(-2),
            labelIDs: featureLabel
        ), in: app)
        try tasks.setStatus(design, to: .done)

        let onboarding = try tasks.create(TaskDraft(
            title: String(localized: "Build onboarding flow", bundle: .module, comment: "Sample task"),
            details: String(localized: "Three screens, skippable, works with VoiceOver.", bundle: .module, comment: "Sample task description"),
            priority: .high,
            startDate: day(-3),
            dueDate: day(0),
            reminderDate: day(0, hour: 9),
            estimatedHours: 6,
            labelIDs: featureLabel,
            involvedPeople: ["Anna", "Jonas"]
        ), in: app)
        try tasks.setStatus(onboarding, to: .inProgress)
        try tasks.addSubtask(to: onboarding, title: String(localized: "Welcome screen", bundle: .module, comment: "Sample subtask"))
        try tasks.addSubtask(to: onboarding, title: String(localized: "Notification permission", bundle: .module, comment: "Sample subtask"))
        try tasks.addSubtask(to: onboarding, title: String(localized: "Sample data option", bundle: .module, comment: "Sample subtask"))
        if let first = onboarding.sortedSubtasks.first {
            try tasks.toggleSubtask(first)
        }
        try tasks.addQuestion(
            to: onboarding,
            text: String(localized: "Should every screen have a skip button?", bundle: .module, comment: "Sample open question")
        )
        // Written "on another device", so the unread indicator is visible in the sample data.
        let syncedComment = try tasks.addComment(
            to: onboarding,
            text: String(localized: "I uploaded the final illustrations.", bundle: .module, comment: "Sample comment")
        )
        syncedComment.authorDeviceID = Self.sampleOtherDeviceID
        try environment.save()

        let crash = try tasks.create(TaskDraft(
            title: String(localized: "Fix crash when deleting a column", bundle: .module, comment: "Sample task"),
            priority: .urgent,
            dueDate: day(-1),
            labelIDs: bugLabel,
            involvedPeople: ["Mia"]
        ), in: app)
        try tasks.addComment(
            to: crash,
            text: String(localized: "Happens only when the column still contains tasks.", bundle: .module, comment: "Sample comment")
        )

        let review = try tasks.create(TaskDraft(
            title: String(localized: "App Store screenshots", bundle: .module, comment: "Sample task"),
            priority: .medium,
            startDate: day(1),
            dueDate: day(4)
        ), in: app)
        try tasks.setStatus(review, to: .review)
        let sizes = try tasks.addQuestion(
            to: review,
            text: String(localized: "Which device sizes are required?", bundle: .module, comment: "Sample open question")
        )
        try tasks.toggleQuestion(sizes)
        try tasks.addQuestion(
            to: review,
            text: String(localized: "Do we localize the captions?", bundle: .module, comment: "Sample open question")
        )

        let submit = try tasks.create(TaskDraft(
            title: String(localized: "Submit for review", bundle: .module, comment: "Sample task"),
            priority: .high,
            startDate: day(5),
            dueDate: day(6)
        ), in: app)
        try tasks.addDependency(submit, blockedBy: review)
        try tasks.addDependency(submit, blockedBy: crash)

        let points = try projects.addCustomField(
            to: app,
            name: String(localized: "Story points", bundle: .module, comment: "Sample custom field"),
            type: .number
        )
        try tasks.setCustomFieldValue("5", for: points, on: onboarding)
        try tasks.setCustomFieldValue("3", for: points, on: crash)

        let marketing = try projects.create(ProjectDraft(
            name: String(localized: "Website Relaunch", bundle: .module, comment: "Sample project"),
            colorHex: ColorPalette.orange,
            symbolName: "paintbrush",
            dueDate: day(45)
        ), in: work)
        try tasks.create(TaskDraft(
            title: String(localized: "Collect customer testimonials", bundle: .module, comment: "Sample task"),
            priority: .low,
            dueDate: day(10)
        ), in: marketing)
        try tasks.create(TaskDraft(
            title: String(localized: "Weekly team sync", bundle: .module, comment: "Sample task"),
            priority: .medium,
            dueDate: day(2, hour: 10),
            recurrence: RecurrenceRule(frequency: .weekly)
        ), in: marketing)

        try templates.create(TemplateDraft(
            name: String(localized: "Bug report", bundle: .module, comment: "Sample template"),
            category: .bug,
            taskTitle: String(localized: "Bug: ", bundle: .module, comment: "Sample template task title"),
            taskDetails: String(localized: "Steps to reproduce:\nExpected result:\nActual result:", bundle: .module, comment: "Sample template details"),
            priority: .high,
            subtaskTitles: [
                String(localized: "Reproduce", bundle: .module, comment: "Sample template subtask"),
                String(localized: "Write a failing test", bundle: .module, comment: "Sample template subtask"),
                String(localized: "Fix and verify", bundle: .module, comment: "Sample template subtask"),
            ]
        ), in: work)

        // Personal
        let personal = try workspaces.create(
            name: String(localized: "Personal", bundle: .module, comment: "Sample workspace"),
            colorHex: ColorPalette.green,
            symbolName: "house",
            addDefaultLabels: false
        )
        let home = try projects.create(ProjectDraft(
            name: String(localized: "Moving", bundle: .module, comment: "Sample project"),
            colorHex: ColorPalette.teal,
            symbolName: "house",
            dueDate: day(20)
        ), in: personal)
        try tasks.create(TaskDraft(
            title: String(localized: "Cancel internet contract", bundle: .module, comment: "Sample task"),
            priority: .medium,
            dueDate: day(3)
        ), in: home)
        try tasks.create(TaskDraft(
            title: String(localized: "Book moving van", bundle: .module, comment: "Sample task"),
            priority: .high,
            dueDate: day(0, hour: 12)
        ), in: home)

        Log.services.notice("Sample data created")
    }

    /// Author of the sample comment that shows up as unread.
    static let sampleOtherDeviceID = "sample-data"
}
#endif
