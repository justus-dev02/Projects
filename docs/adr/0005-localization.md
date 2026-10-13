# ADR 0005 – Localization (English and German)

- Status: accepted
- Date: 2026-10-08

## Decision

- English is the development language; every module has its own `Localizable.xcstrings`
  (`String(localized:bundle: .module)` in packages, `LocalizedStringKey` in SwiftUI).
- German uses the informal "du", matching Apple's current German UI.
- Plurals use catalog variations ("1 Aufgabe" / "3 Aufgaben"); multiple arguments use positional
  specifiers (`%1$@`, `%2$lld`) where German word order differs.
- Persisted values are language independent: enums store raw values, activity entries store a kind
  plus raw detail and are rendered at display time, custom field numbers are stored as `1.5` and
  parsed from the user's locale (`1,5` in German).
- Dates and numbers are formatted with `FormatStyle`, so they follow the region. Calendars respect
  the first weekday (Monday in Germany).
- The language follows the system. The app does not override it, because only the system setting
  switches the language of `String(localized:)`, App Intents and widgets consistently.
- `scripts/check_localizations.py` fails the build in CI if a key used in code is missing,
  untranslated, or has mismatching format specifiers. UI tests run in both languages.
