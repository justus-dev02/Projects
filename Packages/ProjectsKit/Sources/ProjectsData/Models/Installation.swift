import Foundation

/// The app installation the code runs in. Comments remember the installation that wrote them, so a
/// comment that arrives from another device through iCloud can be shown as unread.
///
/// `installedAt` makes the unread state robust: comments created before this installation existed
/// (synced history, a restored backup, the user's own comments before a reinstall) count as read.
/// Only comments written elsewhere *after* this installation started are new to the user.
nonisolated public struct Installation: Equatable, Sendable {
    public let id: String
    public let installedAt: Date

    public init(id: String, installedAt: Date) {
        self.id = id
        self.installedAt = installedAt
    }

    /// Used where no installation is known (previews, extensions that never show comments).
    /// Its empty identifier never matches an author, and `distantFuture` marks every comment as read.
    public static let unknown = Installation(id: "", installedAt: .distantFuture)
}
