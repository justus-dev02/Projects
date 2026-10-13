// swift-tools-version: 6.2
import PackageDescription

/// ProjectsKit bundles everything that is shared between the app, the widget extension and the tests.
///
/// - `ProjectsCore`: pure domain logic (value types, rules, calculations). No UI, no persistence.
/// - `ProjectsData`: SwiftData schema, migrations, container setup and the services that mutate data.
/// - `ProjectsDesignSystem`: design tokens and reusable SwiftUI components.
let package = Package(
    name: "ProjectsKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("26.2"),
        .macOS("26.2"),
    ],
    products: [
        .library(name: "ProjectsCore", targets: ["ProjectsCore"]),
        .library(name: "ProjectsData", targets: ["ProjectsData"]),
        .library(name: "ProjectsDesignSystem", targets: ["ProjectsDesignSystem"]),
    ],
    targets: [
        .target(
            name: "ProjectsCore",
            resources: [.process("Resources")]
        ),
        // Not bound to the main actor: the same services run on the main context for the UI and in
        // `BackgroundStore` (a model actor) for heavy work such as backups and imports.
        .target(
            name: "ProjectsData",
            dependencies: ["ProjectsCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "ProjectsDesignSystem",
            dependencies: ["ProjectsCore"],
            resources: [.process("Resources")],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "ProjectsCoreTests",
            dependencies: ["ProjectsCore"]
        ),
        .testTarget(
            name: "ProjectsDataTests",
            dependencies: ["ProjectsData"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "ProjectsDesignSystemTests",
            dependencies: ["ProjectsDesignSystem"],
            exclude: ["__Snapshots__"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
