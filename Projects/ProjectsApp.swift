//
//  ProjectsApp.swift
//  Projects
//
//  TaskFlow - Multi-Platform Task Management App
//

import SwiftUI
import SwiftData

@main
struct ProjectsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Workspace.self,
            WorkspaceMember.self,
            Project.self,
            ProjectMember.self,
            BoardColumn.self,
            Task.self,
            Subtask.self,
            Comment.self,
            Attachment.self,
            TaskLabel.self,
            TaskCollaborator.self,
            ActivityLog.self,
            Label.self,
            NotificationModel.self,
            SavedView.self,
            // New models for advanced features
            TaskDependency.self,
            RecurringTask.self,
            CustomFieldDefinition.self,
            CustomFieldValue.self,
            TaskTemplate.self,
            Invitation.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            //RootContentView()
            DashboardView()
                .modelContainer(sharedModelContainer)
#if os(macOS)
                .frame(minWidth: 1000, minHeight: 700)
#endif
        }
    }
}
