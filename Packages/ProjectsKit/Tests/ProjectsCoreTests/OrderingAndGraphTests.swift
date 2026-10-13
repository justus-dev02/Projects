import Foundation
import SwiftUI // Reference implementation of `move(fromOffsets:toOffset:)`
import Testing
@testable import ProjectsCore

@Suite("OrderedMove")
struct OrderedMoveTests {
    @Test(arguments: [
        ("c", 0, ["c", "a", "b", "d"]),
        ("a", 3, ["b", "c", "d", "a"]),
        ("a", 99, ["b", "c", "d", "a"]),
        ("b", -4, ["b", "a", "c", "d"]),
        ("x", 1, ["a", "b", "c", "d"]),
    ])
    func moveWithinList(id: String, index: Int, expected: [String]) {
        #expect(OrderedMove.move(id, in: ["a", "b", "c", "d"], to: index) == expected)
    }

    @Test func transferBetweenLists() {
        let result = OrderedMove.transfer("b", from: ["a", "b", "c"], to: ["x", "y"], at: 1)
        #expect(result.source == ["a", "c"])
        #expect(result.destination == ["x", "b", "y"])
    }

    @Test func transferClampsIndexAndAvoidsDuplicates() {
        let result = OrderedMove.transfer("b", from: ["b"], to: ["b", "x"], at: 50)
        #expect(result.source.isEmpty)
        #expect(result.destination == ["x", "b"])
    }

    @Test("Matches the semantics of SwiftUI's onMove")
    func indexSetMoves() {
        let ids = ["a", "b", "c", "d", "e"]
        var reference = ids
        reference.move(fromOffsets: IndexSet([1, 3]), toOffset: 5)
        #expect(OrderedMove.move(ids, fromOffsets: IndexSet([1, 3]), toOffset: 5) == reference)

        var reference2 = ids
        reference2.move(fromOffsets: IndexSet([4]), toOffset: 0)
        #expect(OrderedMove.move(ids, fromOffsets: IndexSet([4]), toOffset: 0) == reference2)
    }
}

@Suite("DependencyGraph")
struct DependencyGraphTests {
    @Test func selfDependencyIsACycle() {
        #expect(DependencyGraph.wouldCreateCycle(task: 1, blockedBy: 1, blockers: [:]))
    }

    @Test func directCycle() {
        // 2 is blocked by 1. Making 1 blocked by 2 closes the loop.
        #expect(DependencyGraph.wouldCreateCycle(task: 1, blockedBy: 2, blockers: [2: [1]]))
    }

    @Test func transitiveCycle() {
        // 3 ← 2 ← 1 (3 blocked by 2, 2 blocked by 1). Blocking 1 by 3 is a cycle.
        let blockers: [Int: Set<Int>] = [3: [2], 2: [1]]
        #expect(DependencyGraph.wouldCreateCycle(task: 1, blockedBy: 3, blockers: blockers))
        #expect(!DependencyGraph.wouldCreateCycle(task: 3, blockedBy: 1, blockers: blockers))
    }

    @Test func diamondIsNotACycle() {
        let blockers: [Int: Set<Int>] = [4: [2, 3], 2: [1], 3: [1]]
        #expect(!DependencyGraph.wouldCreateCycle(task: 4, blockedBy: 1, blockers: blockers))
    }
}

@Suite("SparseOrder")
struct SparseOrderTests {
    @Test func theFirstItemGetsZero() {
        #expect(SparseOrder.key(insertingAt: 0, between: []) == 0)
    }

    @Test func appendingAndPrependingKeepAFullGap() {
        let orders = [0, SparseOrder.spacing]
        #expect(SparseOrder.key(insertingAt: 2, between: orders) == 2 * SparseOrder.spacing)
        #expect(SparseOrder.key(insertingAt: 0, between: orders) == -SparseOrder.spacing)
        #expect(SparseOrder.appendKey(after: orders) == 2 * SparseOrder.spacing)
        #expect(SparseOrder.appendKey(after: []) == 0)
    }

    @Test func insertingBetweenTakesTheMidpoint() {
        #expect(SparseOrder.key(insertingAt: 1, between: [0, 100]) == 50)
        #expect(SparseOrder.key(insertingAt: 1, between: [0, 3]) == 1)
    }

    @Test func adjacentNeighboursNeedARenumbering() {
        #expect(SparseOrder.key(insertingAt: 1, between: [4, 5]) == nil)
        #expect(SparseOrder.key(insertingAt: 1, between: [5, 5]) == nil)
        #expect(SparseOrder.renumbered(count: 3) == [0, SparseOrder.spacing, 2 * SparseOrder.spacing])
    }

    @Test func indexesAreClamped() {
        #expect(SparseOrder.key(insertingAt: 99, between: [0]) == SparseOrder.spacing)
        #expect(SparseOrder.key(insertingAt: -3, between: [0]) == -SparseOrder.spacing)
    }

    @Test("Sixteen insertions fit into one gap")
    func repeatedInsertionsIntoTheSameGap() {
        var orders = [0, SparseOrder.spacing]
        for _ in 0..<16 {
            let key = SparseOrder.key(insertingAt: 1, between: orders)
            #expect(key != nil)
            orders.insert(key ?? 0, at: 1)
        }
        #expect(orders == orders.sorted())
    }
}
