# Contributing

## Setup

The project builds without an Apple Developer account. To sign with your team, copy
`Config/Local.xcconfig.example` to `Config/Local.xcconfig` (ignored by Git) and set
`DEVELOPMENT_TEAM` and `PROJECTS_BUNDLE_ID`. Never commit a team ID or a personal identifier.

## Workflow

- Branch from `main`: `feature/<topic>`, `fix/<topic>`.
- Open a pull request; CI must be green before merging.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org):
  `feat: add timeline zoom`, `fix(data): keep tasks when deleting a column`, `test: …`, `docs: …`, `refactor: …`.

## Before pushing

```bash
swiftlint lint --strict
(cd Packages/ProjectsKit && swift test)
xcodebuild test -scheme Projects -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme Projects -destination 'platform=macOS'
```

## Adding user-facing text

1. Write the English text in code (`Text("…")`, `String(localized: "…")`, in packages with `bundle: .module`).
2. Build in Xcode – the key appears in the module's `.xcstrings` file.
3. Add the German translation in the String Catalog editor (plural variations where a number is involved).
4. Run `scripts/check_localizations.py <DerivedData>`.

## Changing the data model

Never edit a released `SchemaV…`. See the steps in `Packages/ProjectsKit/Sources/ProjectsData/Schema/MigrationPlan.swift`.
