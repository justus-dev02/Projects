# ADR 0001 – Modular architecture with a local Swift package

- Status: accepted
- Date: 2026-10-08

## Context

Version 1 kept models, services and views in the app target. View models lived inside view files,
writes happened both in services and directly in views (`modelContext.insert` in 31 places), and the
tests did not compile, so none of the rules were verified. A widget extension and App Intents need
the same data logic outside the app process.

## Decision

- Split into `ProjectsCore` (pure logic), `ProjectsData` (SwiftData + services) and
  `ProjectsDesignSystem` (UI components) inside the local package `Packages/ProjectsKit`.
- **Read with `@Query`, write through services.** Views do not mutate models directly.
- Feature state that is not persisted lives in the view (`@State`) or in small `@Observable` types;
  there is no 1:1 "ViewModel per view" layer, because `@Query` already provides observable data.
- A single composition root (`AppDependencies`) injected through the SwiftUI environment.
- Swift 6 language mode with `MainActor` default isolation for UI and data modules; Core is
  nonisolated and `Sendable`.

## Consequences

- Business rules are tested with `swift test` in a few seconds without a simulator.
- The widget and App Intents reuse the services instead of duplicating logic.
- A reviewer can find all write paths in `ProjectsData/Services`.
- Package test targets are run with `swift test`; Xcode test plans of the app project do not pick
  them up (verified with `xcodebuild -only-testing:ProjectsCoreTests`), so CI runs both.
