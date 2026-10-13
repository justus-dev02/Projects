import Foundation

/// Sort keys with gaps, so moving an item only changes that item.
///
/// Dense keys (0, 1, 2, …) force every item after the insertion point to be rewritten. With iCloud
/// sync each rewritten item is a record that can conflict with an edit on another device. Sparse
/// keys leave room between neighbours: a moved item takes the midpoint of its new neighbours, and
/// only when two neighbours are directly adjacent does the list get renumbered once.
public enum SparseOrder {
    /// The distance between keys of items appended at the end or renumbered. 2¹⁶ allows 16
    /// consecutive insertions into the same gap before a renumbering is needed.
    public static let spacing = 1 << 16

    /// The key for an item inserted at `index` into a list whose keys are `orders`.
    ///
    /// - Parameters:
    ///   - index: The final position of the item. Clamped to `0...orders.count`.
    ///   - orders: The keys of the other items in ascending order, without the moved item.
    /// - Returns: The new key, or `nil` when the neighbours have no free key between them; then call
    ///   ``renumbered(count:)`` for the whole list.
    public static func key(insertingAt index: Int, between orders: [Int]) -> Int? {
        let position = min(max(index, 0), orders.count)
        let before = position > 0 ? orders[position - 1] : nil
        let after = position < orders.count ? orders[position] : nil
        switch (before, after) {
        case (nil, nil):
            return 0
        case let (before?, nil):
            let (sum, overflow) = before.addingReportingOverflow(spacing)
            return overflow ? nil : sum
        case let (nil, after?):
            let (difference, overflow) = after.subtractingReportingOverflow(spacing)
            return overflow ? nil : difference
        case let (before?, after?):
            guard after > before, after - before > 1 else { return nil }
            return before + (after - before) / 2
        }
    }

    /// The key for an item appended after all items with the given keys.
    public static func appendKey(after orders: some Sequence<Int>) -> Int {
        guard let last = orders.max() else { return 0 }
        let (sum, overflow) = last.addingReportingOverflow(spacing)
        return overflow ? last : sum
    }

    /// Evenly spaced keys for `count` items, used when a gap is used up.
    public static func renumbered(count: Int) -> [Int] {
        (0..<count).map { $0 * spacing }
    }
}
