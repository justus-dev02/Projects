import SwiftUI
import ProjectsDesignSystem

/// Lists MetricKit reports (crashes, hangs, performance metrics) received by the app.
struct DiagnosticsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var reports: [URL] = []

    var body: some View {
        PageScrollView {
            PageHeader(
                eyebrow: Text("Diagnostics"),
                title: Text("\(reports.count) reports")
            )
            CardSection(title: Text("App")) {
                CardRows {
                    if let storeURL = dependencies.storeURL {
                        LabeledContent("Database", value: storeURL.lastPathComponent)
                            .cardRow()
                    }
                    LabeledContent("Spotlight & widgets", value: String(localized: "Active"))
                        .cardRow()
                }
            }
            CardSection(
                title: Text("MetricKit Reports"),
                footer: Text("Reports stay on this device. Share one with the developer if something goes wrong.")
            ) {
                CardRows {
                    if reports.isEmpty {
                        Text("No reports received yet. The system delivers them at most once a day.")
                            .foregroundStyle(.secondary)
                            .cardRow()
                    }
                    ForEach(reports, id: \.self) { url in
                        ShareLink(item: url) {
                            Label(url.deletingPathExtension().lastPathComponent, systemImage: "doc.text")
                                .cardRow()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            if !reports.isEmpty {
                CardSection(title: nil) {
                    Button("Delete Reports", role: .destructive) {
                        dependencies.diagnostics.deleteAll()
                        reports = dependencies.diagnostics.reports
                    }
                    .buttonStyle(.borderless)
                    .cardRow()
                }
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear {
            reports = dependencies.diagnostics.reports
        }
    }
}
