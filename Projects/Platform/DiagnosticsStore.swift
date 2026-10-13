import Foundation
import MetricKit
import OSLog

/// Receives MetricKit diagnostics (crashes, hangs, disk write exceptions) and keeps the latest
/// payloads as JSON so they can be exported from Settings → Diagnostics. No data leaves the
/// device unless the user shares a file.
final class DiagnosticsStore: NSObject, MXMetricManagerSubscriber {
    static let maximumFiles = 20

    let directory: URL
    private let logger = Logger(subsystem: SharedConfiguration.logSubsystem, category: "diagnostics")

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Diagnostics", directoryHint: .isDirectory)) {
        self.directory = directory
        super.init()
    }

    func start() {
        MXMetricManager.shared.add(self)
    }

    var reports: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        return files.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func deleteAll() {
        for url in reports {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let representations = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            for data in representations {
                self.store(data, prefix: "diagnostic")
            }
        }
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let representations = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            for data in representations {
                self.store(data, prefix: "metrics")
            }
        }
    }

    func store(_ data: Data, prefix: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = "\(Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))-\(prefix).json"
                .replacing(":", with: "-")
            try data.write(to: directory.appending(path: name), options: .atomic)
            for old in reports.dropFirst(Self.maximumFiles) {
                try? FileManager.default.removeItem(at: old)
            }
            logger.notice("Stored \(prefix, privacy: .public) payload")
        } catch {
            logger.error("Storing diagnostics failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
