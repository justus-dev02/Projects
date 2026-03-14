//
//  SettingsView.swift
//  Projects
//
//  TaskFlow - Settings View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Settings View Model
@MainActor
class SettingsViewModel: ObservableObject {
    @Published var user: User?
    @Published var showingLogoutAlert = false
    @Published var showingDeleteAccountAlert = false

    private let authService: AuthService
    private let dataService: DataService

    init(
        modelContext: ModelContext? = nil,
        authService: AuthService? = nil,
        dataService: DataService? = nil
    ) {
        let context = modelContext ?? DataService().modelContext
        self.authService = authService ?? AuthService(modelContext: context)
        self.dataService = dataService ?? DataService(modelContext: context)
        self.user = self.authService.currentUser
    }
    
    func logout() {
        _ = try? authService.logout()
        user = nil
    }

    func deleteAccount() throws {
        try authService.deleteAccount()
        user = nil
    }

    func updateDisplayName(_ name: String) throws {
        try authService.updateProfile(displayName: name)
        user = authService.currentUser
    }
    
    func updateAvatarColor(_ color: String) throws {
        try authService.updateProfile(avatarColor: color)
        user = authService.currentUser
    }
}

// MARK: - Settings View (Lade-Logik)
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    // Sobald das ViewModel da ist, rufen wir die eigentliche Form auf
                    SettingsFormView(viewModel: vm)
                } else {
                    ProgressView("Lade Einstellungen...")
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = SettingsViewModel(modelContext: modelContext)
                }
            }
        }
    }
}

// MARK: - Settings Form View (Eigentliche UI)
struct SettingsFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Hier ist es KEIN Optional mehr! Bindings ($) funktionieren hier nativ.
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            // Profile Section
            Section {
                profileSection
            } header: {
                Text("Profile")
            }

            // Preferences Section
            Section {
                appearanceSection
                notificationsSection
            } header: {
                Text("Preferences")
            }

            // Data Section
            Section {
                dataSection
            } header: {
                Text("Data")
            }

            // About Section
            Section {
                aboutSection
            } header: {
                Text("About")
            }

            // Danger Zone
            Section {
                dangerZone
            } header: {
                Text("Danger Zone")
            }
        }
        .navigationTitle("Settings")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        // Alerts zentral an die Form gehängt
        .alert("Logout", isPresented: $viewModel.showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                viewModel.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Delete Account", isPresented: $viewModel.showingDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                try? viewModel.deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: TaskFlowSpacing.large) {
            if let user = viewModel.user {
                TFUserAvatar(user: user, size: .xLarge)

                VStack(spacing: TaskFlowSpacing.xs) {
                    Text(user.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)

                    Text(user.email)
                        .font(.system(size: 13))
                        .foregroundColor(TaskFlowColors.textTertiary)

                    TFStatusBadge(status: user.role, size: .small)
                }
            }

            TFTextField(
                title: "Display Name",
                text: .init(
                    get: { viewModel.user?.displayName ?? "" },
                    set: { try? viewModel.updateDisplayName($0) }
                )
            )

            TFColorPicker(
                title: "Avatar Color",
                selectedColor: .init(
                    get: { viewModel.user?.avatarColor ?? "#2D5BFF" },
                    set: { try? viewModel.updateAvatarColor($0) }
                )
            )
        }
        .padding(.vertical, TaskFlowSpacing.large)
    }
    
    // MARK: - Appearance Section
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            HStack {
                SwiftUI.Label("Dark Mode", systemImage: "moon.fill")
                    .foregroundColor(TaskFlowColors.textPrimary)
                Spacer()
                Text("System")
                    .foregroundColor(TaskFlowColors.textTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
        }
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: TaskFlowSpacing.medium) {
            Toggle("Push Notifications", isOn: .constant(true))
                .foregroundColor(TaskFlowColors.textPrimary)

            Toggle("Email Notifications", isOn: .constant(false))
                .foregroundColor(TaskFlowColors.textPrimary)

            Toggle("Due Date Reminders", isOn: .constant(true))
                .foregroundColor(TaskFlowColors.textPrimary)
        }
    }

    // MARK: - Data Section
    private var dataSection: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Button(action: {
                // Export data
            }) {
                HStack {
                    SwiftUI.Label("Export Data", systemImage: "square.and.arrow.up")
                        .foregroundColor(TaskFlowColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }

            Button(action: {
                // Import data
            }) {
                HStack {
                    SwiftUI.Label("Import Data", systemImage: "square.and.arrow.down")
                        .foregroundColor(TaskFlowColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            HStack {
                SwiftUI.Label("Version", systemImage: "info.circle")
                    .foregroundColor(TaskFlowColors.textPrimary)
                Spacer()
                Text("1.0.0")
                    .foregroundColor(TaskFlowColors.textTertiary)
            }

            Link(destination: URL(string: "https://taskflow.dev")!) {
                HStack {
                    SwiftUI.Label("Website", systemImage: "globe")
                        .foregroundColor(TaskFlowColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
            
            Link(destination: URL(string: "https://github.com/taskflow")!) {
                HStack {
                    SwiftUI.Label("Source Code", systemImage: "chevron.left.slash.chevron.right")
                        .foregroundColor(TaskFlowColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .foregroundColor(TaskFlowColors.textTertiary)
                }
            }
        }
    }

    // MARK: - Danger Zone
    private var dangerZone: some View {
        VStack(spacing: TaskFlowSpacing.medium) {
            Button(role: .destructive) {
                viewModel.showingLogoutAlert = true
            } label: {
                HStack {
                    SwiftUI.Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                }
            }
            .foregroundColor(TaskFlowColors.error)

            Button(role: .destructive) {
                viewModel.showingDeleteAccountAlert = true
            } label: {
                HStack {
                    SwiftUI.Label("Delete Account", systemImage: "trash")
                    Spacer()
                }
            }
            .foregroundColor(TaskFlowColors.error)
        }
    }
}

// MARK: - Preview
#Preview("Settings") {
    SettingsView()
}
