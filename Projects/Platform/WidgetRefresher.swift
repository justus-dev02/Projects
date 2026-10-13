import Foundation
import WidgetKit

/// Reloads widget timelines after changes, coalescing bursts of changes into one reload.
final class WidgetRefresher {
    private var pending: Task<Void, Never>?

    func setNeedsReload() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadTimelines(ofKind: SharedConfiguration.todayWidgetKind)
        }
    }
}
