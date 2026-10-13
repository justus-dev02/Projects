import SwiftUI
import Testing
import ProjectsCore
@testable import ProjectsDesignSystem

@Suite("Component snapshots", .disabled(if: Snapshot.isSkipped, "Snapshots disabled via PROJECTS_SKIP_SNAPSHOTS"))
struct ComponentSnapshotTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func badges(colorScheme: ColorScheme) throws {
        let view = VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(TaskStatus.allCases) { StatusBadge($0) }
            }
            HStack {
                ForEach(TaskPriority.allCases) { PriorityBadge($0) }
            }
            HStack {
                LabelChip(name: "Bug", colorHex: ColorPalette.red)
                LabelChip(name: "Docs", colorHex: ColorPalette.yellow)
                LabelChip(name: "Feature", colorHex: ColorPalette.indigo)
            }
        }
        .padding()
        try Snapshot.verify(view, named: "badges-\(colorScheme)", size: CGSize(width: 420, height: 130), colorScheme: colorScheme)
    }

    @Test func progress() throws {
        let view = HStack(spacing: 24) {
            TFProgressRing(progress: 0)
            TFProgressRing(progress: 0.42)
            TFProgressRing(progress: 1, tint: .green)
            TFProgressBar(progress: 0.66).frame(width: 120)
        }
        .padding()
        try Snapshot.verify(view, named: "progress", size: CGSize(width: 360, height: 90))
    }

    @Test func iconTilesAndStatTile() throws {
        let view = HStack(spacing: 16) {
            IconTile(systemImage: "briefcase", colorHex: ColorPalette.indigo)
            IconTile(systemImage: "house", colorHex: ColorPalette.green, size: 48)
            TFStatTile("Overdue", value: 3, systemImage: "exclamationmark.circle", tint: .red)
                .frame(width: 140)
        }
        .padding()
        try Snapshot.verify(view, named: "tiles", size: CGSize(width: 320, height: 160))
    }
}
