import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem

// The page layout of the main tabs (Today, Tasks, Projects, Templates): a white scrolling page
// with a header sentence, optional statistic tiles and white cards with a title and subtitle.

/// A scrolling page with the standard padding and a readable maximum width.
///
/// The stack is lazy, so sections far below the visible area (and the rows of long cards that use
/// ``LazyCardRows``) are only created when they scroll into view.
struct PageScrollView<Content: View>: View {
    var maxWidth: CGFloat = 900
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TFSpacing.xLarge) {
                content
            }
            .padding()
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(TFColor.background)
    }
}

/// A small line above a bold sentence, e.g. the date and "4 tasks need your attention."
struct PageHeader: View {
    let eyebrow: Text
    let title: Text

    var body: some View {
        VStack(alignment: .leading, spacing: TFSpacing.xSmall) {
            eyebrow
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            title
                .font(.title2.weight(.bold))
        }
        .accessibilityElement(children: .combine)
    }
}

/// Statistic tiles in an adaptive grid.
struct StatTileGrid<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: TFSpacing.medium)], spacing: TFSpacing.medium) {
            content
        }
    }
}

/// A titled card. The content is laid out vertically without spacing; use ``CardDivider``
/// between rows.
struct CardSection<Content: View, Accessory: View>: View {
    /// `nil` shows the card without a heading, e.g. for the first card of a detail page.
    let title: Text?
    var subtitle: Text?
    /// A short explanation below the card.
    var footer: Text?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TFSpacing.small) {
            if title != nil || subtitle != nil {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: TFSpacing.xxSmall) {
                        title?.font(.headline)
                        if let subtitle {
                            subtitle.font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    accessory
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .tfCard(padding: TFSpacing.medium)
            if let footer {
                footer
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TFSpacing.xSmall)
            }
        }
    }
}

extension CardSection where Accessory == EmptyView {
    init(title: Text?, subtitle: Text? = nil, footer: Text? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, subtitle: subtitle, footer: footer, accessory: { EmptyView() }, content: content)
    }
}

// MARK: - Rows inside cards

extension View {
    /// The standard height and alignment of a row inside a card.
    func cardRow() -> some View {
        padding(.vertical, TFSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .contentShape(.rect)
    }

    /// Text fields inside cards: no border, the card is the container.
    func cardTextField() -> some View {
        textFieldStyle(.plain)
    }

    /// The page of an editor sheet. On the Mac sheets need a minimum size.
    func sheetPage() -> some View {
        #if os(macOS)
        frame(minWidth: 480, minHeight: 520)
        #else
        self
        #endif
    }
}

/// A label on the leading edge and a menu picker showing the current value on the trailing edge.
struct CardPicker<Value: Hashable, Options: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Value
    @ViewBuilder var options: Options

    var body: some View {
        LabeledContent(title) {
            Picker(title, selection: $selection) {
                options
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .cardRow()
    }
}

/// A row that navigates somewhere, with a chevron like a list row.
struct CardNavigationRow<Label: View>: View {
    let route: Route
    @ViewBuilder var label: Label

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: TFSpacing.medium) {
                label
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .cardRow()
        }
        .buttonStyle(.plain)
    }
}

/// A row with a leading symbol and a text field that adds an item on Return, e.g. "Add subtask".
struct CardAddField: View {
    let systemImage: String
    let prompt: LocalizedStringKey
    @Binding var text: String
    var axis: Axis = .horizontal
    var identifier: String?
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: TFSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(TFColor.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, axis: axis)
                .lineLimit(1...4)
                .cardTextField()
                .onSubmit(onSubmit)
                .submitLabel(.done)
                .accessibilityIdentifier(identifier ?? "")
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: onSubmit) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(TFColor.accent)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Add"))
            }
        }
        .cardRow()
    }
}

/// Puts a ``CardDivider`` between its rows (not above the first or below the last).
struct CardRows<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Group(subviews: content) { subviews in
            ForEach(subviews) { subview in
                if subview.id != subviews.first?.id {
                    CardDivider()
                }
                subview
            }
        }
    }
}

/// Rows of a card that can grow long (task lists): created lazily, with a divider between rows.
struct LazyCardRows<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(data) { element in
                if element.id != data.first?.id {
                    CardDivider()
                }
                row(element)
            }
        }
    }
}

/// The separator between rows inside a card.
struct CardDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, TFSpacing.xxSmall)
    }
}

/// A statistic tile that also works as a quick filter: tapping it selects or clears the filter.
struct FilterStatTile: View {
    let title: LocalizedStringKey
    let value: Int
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TFStatTile(title, value: value, systemImage: systemImage, tint: tint)
                .overlay {
                    RoundedRectangle(cornerRadius: TFRadius.large)
                        .strokeBorder(tint, lineWidth: isSelected ? 2 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The header of a project's scrolling views (list, table, calendar): workspace and project as
/// the small line, open tasks as the sentence, and the completion progress.
struct ProjectPageHeader: View {
    let project: Project

    var body: some View {
        let stats = project.statistics(now: .now, calendar: .current)
        VStack(alignment: .leading, spacing: TFSpacing.medium) {
            PageHeader(
                eyebrow: Text("\(project.workspace?.name ?? "") › \(project.name)"),
                title: stats.open == 0 ? Text("You're all caught up.") : Text("\(stats.open) open tasks")
            )
            HStack(spacing: TFSpacing.medium) {
                TFProgressBar(progress: stats.completionRate, tint: Color(hex: project.colorHex))
                Text("\(stats.completed) of \(stats.total) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
    }
}
