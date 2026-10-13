import Foundation

/// Cycle detection for "task A is blocked by task B" relationships.
public enum DependencyGraph {
    /// Returns `true` when adding the edge "`task` is blocked by `blocker`" would create a cycle.
    ///
    /// - Parameter blockers: For every task, the set of tasks that block it.
    public static func wouldCreateCycle<ID: Hashable>(
        task: ID,
        blockedBy blocker: ID,
        blockers: [ID: Set<ID>]
    ) -> Bool {
        if task == blocker { return true }
        // A cycle appears if `task` is already (transitively) blocking `blocker`,
        // i.e. if `task` is reachable from `blocker` by following "blocked by" edges.
        var stack: [ID] = [blocker]
        var visited: Set<ID> = []
        while let current = stack.popLast() {
            if current == task { return true }
            guard visited.insert(current).inserted else { continue }
            stack.append(contentsOf: blockers[current] ?? [])
        }
        return false
    }
}
