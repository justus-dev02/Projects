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
    @StateObject private var authService = AuthService.shared

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
            SavedView.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environmentObject(authService)
                .modelContainer(sharedModelContainer)
        }
#if os(macOS)
        .frame(minWidth: 1000, minHeight: 700)
#endif
    }
}
