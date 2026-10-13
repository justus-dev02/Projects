# Performance

Measured with `PerformanceTests` (`Packages/ProjectsKit/Tests/ProjectsDataTests`) on 2026-10-08,
MacBook (Apple silicon), macOS 27, debug build, in-memory SQLite store with **10,000 tasks**
(four columns, labels on every third task).

| Operation | How | Time |
|---|---|---|
| Dashboard numbers (5 counts) | `fetchCount` with predicates | 5.5 ms |
| Filtered task list, first page | Predicate (search + priority + open) + sort + `fetchLimit = 50` | 11.8 ms |
| Count of the same filter | `fetchCount` | 2.3 ms |
| JSON backup of all data | `BackupService.exportJSON()` | 3.0 s, 7.4 MB |

The tests fail if the dashboard or the first page take longer than one second, or the export
longer than ten seconds, so regressions surface in CI long before users notice them.

## Design choices that keep it fast

- Filtering, sorting and paging run in SQLite (`TaskQueries`), the task list loads 100 rows at a
  time ("Load More").
- Priority is stored as `Int` so it sorts in the store; due-date sorting puts tasks without a date
  last with an O(n) rotation instead of an in-memory sort.
- Dashboard statistics use `fetchCount` instead of loading tasks.
- Spotlight is re-indexed in batches of 500.
- Widget timelines refresh at midnight and on change (debounced by 500 ms).

## Not yet measured

- Instruments traces (Time Profiler, SwiftUI) on a physical device and with an on-disk store.
- Launch time: `ProjectsLaunchPerformanceTests` records `XCTApplicationLaunchMetric`; the values are
  in the Xcode test report, but no baseline has been committed yet.
- The JSON export is the slowest operation; streaming the encoding per workspace would reduce peak memory.
