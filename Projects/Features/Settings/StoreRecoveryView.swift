import SwiftUI
import ProjectsData
import ProjectsDesignSystem

/// Shown instead of crashing when the database cannot be opened.
struct StoreRecoveryView: View {
    let issue: AppDependencies.StoreIssue
    @State private var confirmsReset = false
    @State private var didReset = false

    var body: some View {
        ContentUnavailableView {
            Label("Database Unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            if didReset {
                Text("The local database was reset. Please restart Projects. If iCloud sync is on, your data will be downloaded again.")
            } else {
                // swiftlint:disable:next line_length
                Text("Projects could not open its database. Restarting the device often helps. If the problem persists, you can reset the local database. Data synced with iCloud is downloaded again afterwards.")
            }
        } actions: {
            if !didReset {
                Button("Reset Local Database", role: .destructive) {
                    confirmsReset = true
                }
                .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TFColor.background)
        .deleteConfirmation(
            "Reset Local Database?",
            message: "Data that has not been synced with iCloud will be lost.",
            isPresented: $confirmsReset
        ) {
            guard case .couldNotOpen(let url) = issue else { return }
            didReset = (try? PersistenceController.destroyStore(at: url)) != nil
        }
    }
}
