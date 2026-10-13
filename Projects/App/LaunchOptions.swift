import Foundation

/// Launch arguments used by UI tests and for local debugging.
///
/// - `-ui-testing`: in-memory store, no onboarding, no system permission prompts.
/// - `-seed-demo-data`: fills the in-memory store with the localized sample data set (debug builds
///   only; the shipped app always starts empty).
enum LaunchOptions {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isUITesting: Bool { arguments.contains("-ui-testing") }
    static var seedDemoData: Bool { arguments.contains("-seed-demo-data") }

    /// `true` while the app is the host of the unit test bundle.
    static var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var usesInMemoryStore: Bool { isUITesting || isHostingUnitTests }
}
