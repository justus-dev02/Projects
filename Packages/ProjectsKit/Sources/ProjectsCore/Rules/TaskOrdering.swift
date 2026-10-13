import Foundation

/// Sort orders that do not depend on the manual board order.
public enum TaskOrdering {
    /// Highest priority first; equal priorities by due date (tasks without one last), then by title.
    /// Used by the project table, which always shows tasks sorted by priority.
    public static func byPriority<Task: TaskFilterable>(_ tasks: [Task]) -> [Task] {
        tasks.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?) where left != right:
                return left < right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}

/// Moving an item one step up or down in a list (context menu alternative to drag and drop).
public enum StepMove {
    public enum Direction: Sendable {
        case upward
        case downward
    }

    /// The item's index after the move, or `nil` when it is already at that end of the list.
    public static func targetIndex(from index: Int, direction: Direction, count: Int) -> Int? {
        guard (0..<count).contains(index) else { return nil }
        switch direction {
        case .upward: return index > 0 ? index - 1 : nil
        case .downward: return index < count - 1 ? index + 1 : nil
        }
    }

    /// The same move expressed as a `List.onMove` destination (an index before the removal).
    public static func onMoveDestination(from index: Int, direction: Direction, count: Int) -> Int? {
        guard let target = targetIndex(from: index, direction: direction, count: count) else { return nil }
        return target > index ? target + 1 : target
    }
}

extension DependencyGraph {
    /// The tasks that may block `task`: every other task that does not block it yet and whose
    /// addition would not create a cycle.
    ///
    /// - Parameters:
    ///   - candidates: All tasks of the project, in the order they should be offered.
    ///   - blockers: For every task, the set of tasks that block it.
    public static func possibleBlockers<ID: Hashable>(
        for task: ID,
        among candidates: [ID],
        blockers: [ID: Set<ID>]
    ) -> [ID] {
        let current = blockers[task] ?? []
        return candidates.filter { candidate in
            candidate != task && !current.contains(candidate)
                && !wouldCreateCycle(task: task, blockedBy: candidate, blockers: blockers)
        }
    }
}
