import Foundation
import Observation
import SwiftUI

/// A short-lived confirmation at the bottom of the window, optionally with an action
/// ("Task deleted – Undo").
struct Toast: Identifiable {
    let id = UUID()
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
}

@Observable
final class ToastCenter {
    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        dismissTask?.cancel()
        withAnimation(.snappy) {
            current = Toast(message: message, actionTitle: actionTitle, action: action)
        }
        AccessibilityNotification.Announcement(message).post()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        withAnimation(.snappy) {
            current = nil
        }
    }

    func runAction() {
        current?.action?()
        dismiss()
    }
}
