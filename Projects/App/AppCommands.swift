import SwiftUI

/// Menu bar commands (macOS, iPadOS with keyboard) and their keyboard shortcuts.
struct AppCommands: Commands {
    let router: AppRouter

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") {
                router.present(.newTask(projectID: nil))
            }
            .keyboardShortcut("n")

            Button("New Project") {
                router.present(.newProject(workspaceID: nil))
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Workspace") {
                router.present(.newWorkspace)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
        }

        CommandGroup(after: .textEditing) {
            Button("Find Tasks") {
                router.requestSearchFocus()
            }
            .keyboardShortcut("f")
        }

        CommandMenu("Go") {
            Button("Today") { router.show(.today) }
                .keyboardShortcut("1")
            Button("Tasks") { router.show(.tasks) }
                .keyboardShortcut("2")
            Button("Projects") { router.show(.projects) }
                .keyboardShortcut("3")
            Button("Templates") { router.show(.templates) }
                .keyboardShortcut("4")
        }

        SidebarCommands()
        ToolbarCommands()
    }
}
