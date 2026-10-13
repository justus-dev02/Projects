import SwiftData
import SwiftUI
import ProjectsCore
import ProjectsData
import ProjectsDesignSystem
import UniformTypeIdentifiers
import UserNotifications

/// App settings: appearance, language, notifications, iCloud sync, backups and diagnostics.
struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system
    @AppStorage(SharedConfiguration.DefaultsKey.iCloudSyncEnabled, store: SharedConfiguration.sharedDefaults)
    private var iCloudSyncEnabled = true

    @State private var export: PendingExport?
    @State private var isImporting = false
    @State private var pendingImport: URL?
    @State private var isWorking = false
    @State private var confirmsReset = false

    var body: some View {
        PageScrollView {
            PageHeader(
                eyebrow: Text("Projects \(Bundle.main.versionDescription)"),
                title: Text("Make Projects yours.")
            )
            appearanceSection
            languageSection
            notificationsSection
            if SharedConfiguration.isCloudSyncAvailable {
                syncSection
            }
            dataSection
            CardSection(title: Text("About")) {
                CardRows {
                    NavigationLink {
                        DiagnosticsView()
                    } label: {
                        HStack {
                            Label("Diagnostics", systemImage: "stethoscope")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .cardRow()
                    }
                    .buttonStyle(.plain)
                    LabeledContent("Version", value: Bundle.main.versionDescription)
                        .cardRow()
                }
            }
        }
        .navigationTitle("Settings")
        .fileExporter(
            isPresented: Binding(get: { export != nil }, set: { if !$0 { export = nil } }),
            document: export?.document,
            contentType: export?.type ?? .json,
            defaultFilename: export?.name
        ) { result in
            if case .failure(let error) = result {
                dependencies.errors.present(error)
            } else {
                dependencies.toasts.show(String(localized: "Export saved"))
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            readImport(result)
        }
        .confirmationDialog(
            "Restore Backup",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible
        ) {
            Button("Add to Existing Data") { runImport(mode: .merge) }
            Button("Replace All Data", role: .destructive) { runImport(mode: .replaceAll) }
        } message: {
            Text("“Add” keeps your data and skips workspaces that already exist. “Replace” deletes all current data first.")
        }
        .deleteConfirmation(
            "Delete All Data?",
            message: "All workspaces, projects and tasks on this device will be deleted. If iCloud sync is on, they are also deleted on your other devices.",
            isPresented: $confirmsReset
        ) {
            dependencies.errors.perform {
                for workspace in try dependencies.workspaces.workspaces(includeArchived: true) {
                    try dependencies.workspaces.delete(workspace)
                }
            }
        }
        .task {
            await dependencies.reminders.refreshAuthorizationStatus()
        }
    }

    // MARK: Sections

    private var appearanceSection: some View {
        CardSection(title: Text("Appearance")) {
            Picker("Appearance", selection: $appearance) {
                ForEach(AppearancePreference.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .cardRow()
        }
    }

    private var languageSection: some View {
        #if os(iOS)
        let footer = Text("Projects is available in English and German. The language is chosen in the iOS Settings app.")
        #else
        let footer = Text("Projects is available in English and German. Choose the language in System Settings › General › Language & Region › Applications.")
        #endif
        return CardSection(title: Text("Language"), footer: footer) {
            CardRows {
                LabeledContent("Language", value: Locale.current.localizedString(forLanguageCode: Bundle.main.preferredLocalizations.first ?? "en") ?? "")
                    .cardRow()
                #if os(iOS)
                Button("Change Language") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderless)
                .cardRow()
                #endif
            }
        }
    }

    private var notificationsSection: some View {
        CardSection(
            title: Text("Notifications"),
            footer: Text("Reminders arrive at the time you set on a task. You can complete or snooze a task directly from the notification.")
        ) {
            CardRows {
                notificationRows
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var notificationRows: some View {
            switch dependencies.reminders.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Label("Reminders are enabled", systemImage: "bell.badge")
                    .cardRow()
            case .denied:
                Label("Notifications are turned off", systemImage: "bell.slash")
                    .foregroundStyle(TFColor.warning)
                    .cardRow()
                #if os(iOS)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .cardRow()
                #endif
            default:
                Button("Allow Reminders") {
                    Task {
                        if await dependencies.reminders.requestAuthorizationIfNeeded() {
                            await dependencies.refreshPlatformState()
                        }
                    }
                }
                .cardRow()
            }
    }

    private var syncSection: some View {
        CardSection(
            title: Text("iCloud"),
            // swiftlint:disable:next line_length
            footer: Text("Keeps your data in sync on all devices signed in to your Apple Account. Changes to this setting take effect after restarting the app.")
        ) {
            CardRows {
                Toggle("iCloud Sync", isOn: $iCloudSyncEnabled)
                    .cardRow()
                LabeledContent("Status") {
                    syncStatus
                }
                .cardRow()
            }
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch dependencies.sync.state {
        case .disabled:
            Text("Off")
        case .unavailable:
            Text("Unavailable")
                .foregroundStyle(TFColor.warning)
        case .syncing:
            HStack {
                ProgressView().controlSize(.small)
                Text("Syncing…")
            }
        case .idle(let lastSync):
            if let lastSync {
                Text("Last synced \(lastSync.formatted(.relative(presentation: .named)))")
            } else {
                Text("Waiting for iCloud")
            }
        case .failed(let message):
            Text(message)
                .foregroundStyle(TFColor.danger)
                .lineLimit(2)
        }
    }

    private var dataSection: some View {
        CardSection(
            title: Text("Data"),
            footer: Text("Backups contain workspaces, projects, tasks, subtasks, comments, labels and templates. Attachments are not included.")
        ) {
            CardRows {
                Button {
                    exportBackup()
                } label: {
                    Label("Export Backup (JSON)", systemImage: "square.and.arrow.up")
                        .cardRow()
                }
                .accessibilityIdentifier("settings.exportBackup")
                Button {
                    isImporting = true
                } label: {
                    Label("Restore Backup", systemImage: "square.and.arrow.down")
                        .cardRow()
                }
                Button {
                    exportCSV()
                } label: {
                    Label("Export Tasks as CSV", systemImage: "tablecells")
                        .cardRow()
                }
                Button(role: .destructive) {
                    confirmsReset = true
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                        .foregroundStyle(TFColor.danger)
                        .cardRow()
                }
            }
            .buttonStyle(.borderless)
            .disabled(isWorking)
        }
        .overlay(alignment: .topTrailing) {
            if isWorking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(Text("Working…"))
            }
        }
    }

    // MARK: Actions

    // Export and import run in the background store; `isWorking` disables the
    // buttons and shows progress meanwhile.

    private func exportBackup() {
        Task {
            isWorking = true
            defer { isWorking = false }
            guard let data = await dependencies.exportBackup() else { return }
            let date = Date.now.formatted(.iso8601.year().month().day())
            export = PendingExport(document: ExportDocument(data: data), type: .json, name: "Projects-Backup-\(date).json")
        }
    }

    private func exportCSV() {
        Task {
            isWorking = true
            defer { isWorking = false }
            guard let data = await dependencies.exportCSV() else { return }
            let date = Date.now.formatted(.iso8601.year().month().day())
            export = PendingExport(document: ExportDocument(data: data), type: .commaSeparatedText, name: "Projects-Tasks-\(date).csv")
        }
    }

    private func readImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            // The file is read in the background once the user chose how to import it.
            pendingImport = url
        case .failure(let error):
            dependencies.errors.present(error)
        }
    }

    private func runImport(mode: BackupService.ImportMode) {
        guard let url = pendingImport else { return }
        pendingImport = nil
        Task {
            isWorking = true
            defer { isWorking = false }
            guard let summary = await dependencies.importBackup(from: url, mode: mode) else { return }
            dependencies.toasts.show(String(
                localized: "Restored \(summary.importedProjects) projects with \(summary.importedTasks) tasks",
                comment: "Toast after restoring a backup"
            ))
        }
    }
}

extension Bundle {
    var versionDescription: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}
