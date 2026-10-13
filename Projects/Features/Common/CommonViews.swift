import SwiftUI
import ProjectsDesignSystem

/// Shown when a route points to something that no longer exists (deleted on another device,
/// stale deep link).
struct NotFoundView: View {
    let title: LocalizedStringKey

    var body: some View {
        ContentUnavailableView(title, systemImage: "questionmark.folder", description: Text("It may have been deleted."))
    }
}

/// A standard "Cancel" / "Save" toolbar for editor sheets.
struct EditorToolbar: ToolbarContent {
    let saveTitle: LocalizedStringKey
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(saveTitle, action: onSave)
                .disabled(!canSave)
                .accessibilityIdentifier("editor.save")
        }
    }
}

extension View {
    /// A destructive confirmation dialog with a localized title and message.
    func deleteConfirmation(
        _ title: LocalizedStringKey,
        message: LocalizedStringKey,
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
                .accessibilityIdentifier("confirm.delete")
        } message: {
            Text(message)
        }
    }
}
