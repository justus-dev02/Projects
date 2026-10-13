import Foundation

/// A cross-process "the store changed" signal between the widget extension and the app.
///
/// Uses a Darwin notification: it carries no data and works while both processes run. The app
/// reacts by reading the store's history (see `ExternalChangeReader`). The name is prefixed with
/// the App Group, which the macOS sandbox requires for notifications between app and extension.
nonisolated enum StoreChangeSignal {
    static var name: CFNotificationName {
        let prefix = SharedConfiguration.appGroupIdentifier ?? SharedConfiguration.logSubsystem
        return CFNotificationName("\(prefix).storeDidChange" as CFString)
    }

    /// Tells other processes that this one saved changes.
    static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), name, nil, nil, true)
    }

    /// Calls `handler` whenever another process posts the signal, until the observation is released.
    static func observe(_ handler: @escaping @Sendable () -> Void) -> Observation {
        Observation(handler: handler)
    }

    final class Observation: Sendable {
        private let handler: @Sendable () -> Void

        fileprivate init(handler: @escaping @Sendable () -> Void) {
            self.handler = handler
            // Darwin callbacks are C functions; the observation itself is passed as context.
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque(),
                { _, observer, _, _, _ in
                    guard let observer else { return }
                    Unmanaged<Observation>.fromOpaque(observer).takeUnretainedValue().handler()
                },
                StoreChangeSignal.name.rawValue,
                nil,
                .deliverImmediately
            )
        }

        deinit {
            CFNotificationCenterRemoveEveryObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                Unmanaged.passUnretained(self).toOpaque()
            )
        }
    }
}
