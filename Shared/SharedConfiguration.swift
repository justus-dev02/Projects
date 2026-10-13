import Foundation
import ProjectsData

/// Identifiers shared by the app and the widget extension.
///
/// Nothing here is hard-coded: the values come from the Info.plist, which Xcode fills from
/// `Config/Projects.xcconfig` (and your `Config/Local.xcconfig`). That way a fork only changes the
/// build settings, never the code.
nonisolated enum SharedConfiguration {
    /// The App Group shared by the app and the widget, or `nil` when the build has none (e.g. an
    /// unsigned local build). Without a group, the app falls back to its own container.
    static let appGroupIdentifier: String? = infoValue(for: "TFAppGroupIdentifier")

    /// The CloudKit container used when iCloud sync is enabled.
    static let iCloudContainerIdentifier: String? = infoValue(for: "TFCloudContainerIdentifier")

    static let todayWidgetKind = "TodayTasksWidget"

    /// The subsystem of all `Logger`s, so Console.app shows the app's messages under its own
    /// bundle identifier.
    static let logSubsystem = Bundle.main.bundleIdentifier ?? "Projects"

    /// Whether this build is signed with the iCloud (CloudKit) and Push Notifications entitlements.
    /// Personal development teams cannot sign them, so they are currently removed from `Config/`.
    /// To re-enable sync: add both capabilities back to the entitlements (see docs/RELEASE.md)
    /// and set this to `true`.
    static let isCloudSyncAvailable = false

    /// Settings both processes read, stored in the App Group.
    static var sharedDefaults: UserDefaults {
        appGroupIdentifier.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// This installation, used to tell comments that arrive from another device through iCloud
    /// from the user's own. Created on first use and kept in local defaults (never synced).
    static var installation: Installation {
        let defaults = sharedDefaults
        if let id = defaults.string(forKey: DefaultsKey.deviceID), !id.isEmpty,
           let since = defaults.object(forKey: DefaultsKey.installedAt) as? Date {
            return Installation(id: id, installedAt: since)
        }
        // Keeps an identifier from before `installedAt` existed; comments up to now count as read.
        let id = defaults.string(forKey: DefaultsKey.deviceID).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
        let installation = Installation(id: id, installedAt: .now)
        defaults.set(installation.id, forKey: DefaultsKey.deviceID)
        defaults.set(installation.installedAt, forKey: DefaultsKey.installedAt)
        return installation
    }

    enum DefaultsKey {
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let deviceID = "deviceID"
        static let installedAt = "installedAt"
    }

    /// Reads a string from the Info.plist, ignoring empty values and unresolved build settings.
    private static func infoValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.contains("$(") else {
            return nil
        }
        return value
    }
}
