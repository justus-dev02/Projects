import Foundation

/// Limits for files attached to tasks. Attachments are synced through iCloud, so they are kept
/// reasonably small.
public enum AttachmentPolicy {
    public static let maxBytes = 25 * 1024 * 1024

    public static func validate(byteCount: Int) throws {
        guard byteCount <= maxBytes else {
            throw ProjectsError.attachmentTooLarge(maxBytes: maxBytes)
        }
    }
}
