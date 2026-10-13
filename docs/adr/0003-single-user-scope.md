# ADR 0003 – Single-user scope; collaboration deferred

- Status: accepted
- Date: 2026-10-08

## Context

Version 1 contained a login (any password worked for any account), workspace members, invitations
and a chat. Without a server none of these could reach a second person; they only looked finished.

## Decision

Remove authentication, members, invitations and chat. Projects is a single-user app whose data
syncs across the user's own devices through iCloud.

## Options for real collaboration later

| Option | Effort | Notes |
|---|---|---|
| CloudKit sharing (`CKShare`) | high | Not supported by SwiftData today; requires `NSPersistentCloudKitContainer` with a shared store, i.e. a Core Data persistence layer behind the existing services. |
| Own backend (e.g. Vapor or Supabase) | high | Accounts, permissions, server-side conflict handling, push. Sign in with Apple for identity. |

Either option replaces only `ProjectsData`'s persistence; services and UI keep their interfaces.

## Consequences

Features shown in the app are features that work. The README does not claim collaboration.
