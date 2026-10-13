import Foundation

/// Pure functions for re-ordering items in lists.
///
/// These helpers compute the new sequence of identifiers. Short lists with dense keys (board
/// columns, custom fields) write `order = index` for every element; tasks and subtasks use the
/// result only to find the new position and then take a key from ``SparseOrder``.
public enum OrderedMove {
    /// Moves `id` to `index` inside `ids`. The index is clamped to the valid range.
    /// Returns `ids` unchanged when `id` is not contained.
    public static func move<ID: Hashable>(_ id: ID, in ids: [ID], to index: Int) -> [ID] {
        guard let currentIndex = ids.firstIndex(of: id) else { return ids }
        var result = ids
        result.remove(at: currentIndex)
        let target = min(max(index, 0), result.count)
        result.insert(id, at: target)
        return result
    }

    /// Moves `id` out of `source` and inserts it into `destination` at `index`.
    ///
    /// When source and destination are the same list, use ``move(_:in:to:)`` instead.
    public static func transfer<ID: Hashable>(
        _ id: ID,
        from source: [ID],
        to destination: [ID],
        at index: Int
    ) -> (source: [ID], destination: [ID]) {
        let newSource = source.filter { $0 != id }
        var newDestination = destination.filter { $0 != id }
        let target = min(max(index, 0), newDestination.count)
        newDestination.insert(id, at: target)
        return (newSource, newDestination)
    }

    /// Applies `IndexSet`-based moves (as produced by `List.onMove`) to an identifier list.
    public static func move<ID: Hashable>(_ ids: [ID], fromOffsets source: IndexSet, toOffset destination: Int) -> [ID] {
        let moving = source.compactMap { ids.indices.contains($0) ? ids[$0] : nil }
        var remaining: [ID] = []
        var insertionIndex = destination
        for (index, id) in ids.enumerated() {
            if source.contains(index) {
                if index < destination { insertionIndex -= 1 }
            } else {
                remaining.append(id)
            }
        }
        let target = min(max(insertionIndex, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: target)
        return remaining
    }
}
