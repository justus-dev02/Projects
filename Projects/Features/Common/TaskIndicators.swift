import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

// Small status indicators shared by the task list, the board and the project table.

/// A dot on the trailing edge of a task that has comments: gray when everything is read, green
/// while a comment from another device has not been viewed.
struct CommentDot: View {
    /// Optional for the same reason as in ``CompletionButton``.
    @Environment(AppDependencies.self) private var dependencies: AppDependencies?
    let task: TaskItem

    var body: some View {
        if task.hasComments {
            let isUnread = task.hasUnreadComments(in: dependencies?.environment.installation ?? .unknown)
            Circle()
                .fill(isUnread ? TFColor.success : Color.gray.opacity(0.55))
                .frame(width: 9, height: 9)
                .overlay {
                    if isUnread {
                        Circle().stroke(TFColor.success.opacity(0.35), lineWidth: 3)
                    }
                }
                .help(isUnread ? Text("Unread comments") : Text("Has comments"))
                .accessibilityLabel(isUnread ? Text("Unread comments") : Text("Has comments"))
        }
    }
}

/// Initials of the people involved in a task, overlapping like a stack of avatars.
struct PeopleBadge: View {
    let names: [String]
    var maxVisible = 3
    var showsNames = false

    var body: some View {
        if !names.isEmpty {
            HStack(spacing: TFSpacing.xSmall) {
                HStack(spacing: -6) {
                    ForEach(names.prefix(maxVisible), id: \.self) { name in
                        PersonAvatar(name: name)
                    }
                    if names.count > maxVisible {
                        Text(verbatim: "+\(names.count - maxVisible)")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .padding(.leading, TFSpacing.small)
                            .foregroundStyle(.secondary)
                    }
                }
                if showsNames {
                    Text(names.formatted(.list(type: .and)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .help(names.formatted(.list(type: .and)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("People: \(names.formatted(.list(type: .and)))"))
        }
    }
}

/// A round avatar with a person's initials. The color is derived from the name, so the same
/// person always gets the same color on every device.
struct PersonAvatar: View {
    let name: String
    var size: CGFloat = 20

    private static let palette = [
        ColorPalette.indigo, ColorPalette.blue, ColorPalette.teal, ColorPalette.green,
        ColorPalette.orange, ColorPalette.pink, ColorPalette.purple,
    ]

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: color), in: .circle)
            .overlay(Circle().stroke(TFColor.surface, lineWidth: 1.5))
            .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    /// `hashValue` changes between launches, so a simple stable sum is used instead.
    private var color: String {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Self.palette[sum % Self.palette.count]
    }
}

/// The number of open questions, highlighted while any are open.
struct QuestionsBadge: View {
    let openCount: Int

    var body: some View {
        if openCount > 0 {
            Label {
                Text(openCount, format: .number)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "questionmark.bubble.fill")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(TFColor.warning)
            .labelStyle(.tfCompact)
            .help(Text("\(openCount) open questions"))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(openCount) open questions"))
        }
    }
}

/// Shows that a task waits for other tasks and, on hover or for VoiceOver, which ones.
struct BlockedBadge: View {
    let task: TaskItem
    var showsText = true

    var body: some View {
        if task.isBlocked, !task.isCompleted {
            let names = task.openBlockers.map(\.title).formatted(.list(type: .and))
            Label {
                if showsText {
                    Text("Blocked")
                }
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(TFColor.warning)
            .labelStyle(.tfCompact)
            .help(Text("Waiting for \(names)"))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Blocked, waiting for \(names)"))
        }
    }
}

/// Edits a list of names: one row per person plus a field to add another.
/// Used by the task editor (on a draft) and by the task detail (through the service).
struct PeopleEditorSection: View {
    let names: [String]
    let onAdd: (String) -> Bool
    let onRemove: (String) -> Void
    @State private var newName = ""

    var body: some View {
        CardSection(title: Text("People Involved")) {
            ForEach(names, id: \.self) { name in
                HStack(spacing: TFSpacing.medium) {
                    PersonAvatar(name: name, size: 28)
                    Text(name)
                    Spacer()
                    Button {
                        onRemove(name)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Remove \(name)"))
                }
                .cardRow()
                .contextMenu {
                    Button("Remove", role: .destructive) { onRemove(name) }
                }
                CardDivider()
            }
            CardAddField(systemImage: "person.badge.plus", prompt: "Add person", text: $newName, identifier: "people.new", onSubmit: add)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
        }
    }

    private func add() {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if onAdd(newName) {
            newName = ""
        }
    }
}
