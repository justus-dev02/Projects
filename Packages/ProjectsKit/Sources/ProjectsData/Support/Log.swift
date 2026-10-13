import OSLog

import Foundation

/// Loggers of the data layer. Visible in Console.app under the bundle identifier of the app (or
/// extension) that runs the code.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Projects"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let services = Logger(subsystem: subsystem, category: "services")
    static let backup = Logger(subsystem: subsystem, category: "backup")
}
