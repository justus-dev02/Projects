//
//  MainNavigationView.swift
//  Projects
//
//  TaskFlow - Main Navigation Component (Bottom Bar for iOS, Top Bar for iPad/macOS)
//

import SwiftUI
import Combine

// MARK: - Navigation Tab Enum
enum MainNavigationTab: Hashable, CaseIterable, Identifiable {
    case dashboard
    case tasks
    case projects
    case messages
    case settings

    var id: Int {
        hashValue
    }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .tasks: return "Tasks"
        case .projects: return "Projects"
        case .messages: return "Messages"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "speedometer"
        case .tasks: return "checkmark.seal.fill"
        case .projects: return "folder.fill"
        case .messages: return "message.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var selectedIcon: String {
        switch self {
        case .dashboard: return "speedometer"
        case .tasks: return "checkmark.seal.fill"
        case .projects: return "folder.fill"
        case .messages: return "message.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main Navigation Bar View Model
@MainActor
class MainNavigationViewModel: ObservableObject {
    @Published var selectedTab: MainNavigationTab = .dashboard
    @Published var badgeCounts: [MainNavigationTab: Int] = [:]

    func setBadgeCount(_ count: Int, for tab: MainNavigationTab) {
        if count > 0 {
            badgeCounts[tab] = count
        } else {
            badgeCounts.removeValue(forKey: tab)
        }
    }

    func updateBadgeCounts() {
        // Update badge counts based on notifications, unread messages, etc.
        // This would be connected to real data in production
        setBadgeCount(3, for: .messages)
    }
}

// MARK: - Main Navigation Bar (Bottom for iOS, Top for iPad/macOS)
struct MainNavigationBar: View {
    @ObservedObject var viewModel: MainNavigationViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var onTabSelected: (MainNavigationTab) -> Void

    var body: some View {
        Group {
            if isRegularSize {
                // iPad/Mac - Top horizontal bar
                topNavigationBar
            } else {
                // iPhone - Bottom tab bar
                bottomTabBar
            }
        }
    }

    private var isRegularSize: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Top Navigation Bar (iPad/Mac)
    private var topNavigationBar: some View {
        HStack(spacing: TaskFlowSpacing.none) {
            ForEach(MainNavigationTab.allCases) { tab in
                TopNavigationItem(
                    tab: tab,
                    isSelected: viewModel.selectedTab == tab,
                    badgeCount: viewModel.badgeCounts[tab],
                    action: {
                        withAnimation(.easeInOut(duration: TaskFlowAnimation.medium)) {
                            viewModel.selectedTab = tab
                            onTabSelected(tab)
                        }
                    }
                )
            }

            Spacer()
        }
        .padding(.horizontal, TaskFlowSpacing.large)
        .padding(.vertical, TaskFlowSpacing.small)
        .background(TaskFlowColors.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(TaskFlowColors.border),
            alignment: .bottom
        )
    }

    // MARK: - Bottom Tab Bar (iPhone)
    private var bottomTabBar: some View {
        HStack(spacing: TaskFlowSpacing.none) {
            ForEach(MainNavigationTab.allCases) { tab in
                BottomTabItem(
                    tab: tab,
                    isSelected: viewModel.selectedTab == tab,
                    badgeCount: viewModel.badgeCounts[tab],
                    action: {
                        withAnimation(.easeInOut(duration: TaskFlowAnimation.medium)) {
                            viewModel.selectedTab = tab
                            onTabSelected(tab)
                        }
                    }
                )
            }
        }
        .padding(.bottom, 0)
        .background(TaskFlowColors.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(TaskFlowColors.border),
            alignment: .top
        )
    }
}

// MARK: - Top Navigation Item
struct TopNavigationItem: View {
    let tab: MainNavigationTab
    let isSelected: Bool
    let badgeCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TaskFlowSpacing.small) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? TaskFlowColors.primary : TaskFlowColors.textSecondary)

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? TaskFlowColors.primary : TaskFlowColors.textSecondary)

                if let badgeCount = badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TaskFlowColors.error)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, TaskFlowSpacing.large)
            .padding(.vertical, TaskFlowSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                    .fill(isSelected ? TaskFlowColors.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bottom Tab Item
struct BottomTabItem: View {
    let tab: MainNavigationTab
    let isSelected: Bool
    let badgeCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? TaskFlowColors.primary : TaskFlowColors.textTertiary)

                    if let badgeCount = badgeCount, badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(.horizontal, 4)
                            .background(TaskFlowColors.error)
                            .clipShape(Circle())
                            .offset(x: 12, y: -12)
                    }
                }

                Text(tab.title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? TaskFlowColors.primary : TaskFlowColors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TaskFlowSpacing.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Adaptive Navigation Container
struct AdaptiveNavigationContainer<Content: View>: View {
    @ObservedObject var navigationViewModel: MainNavigationViewModel
    @ViewBuilder var content: (MainNavigationTab) -> Content
    var onTabSelected: (MainNavigationTab) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if isRegularSize {
                // iPad/Mac - NavigationSplitView or custom layout
                navigationSplitView
            } else {
                // iPhone - TabView style
                tabView
            }
        }
    }

    private var isRegularSize: Bool {
        horizontalSizeClass == .regular
    }

    private var navigationSplitView: some View {
        NavigationSplitView {
            // Sidebar with navigation items
            VStack(spacing: TaskFlowSpacing.none) {
                ForEach(MainNavigationTab.allCases) { tab in
                    SidebarNavigationItem(
                        tab: tab,
                        isSelected: navigationViewModel.selectedTab == tab,
                        badgeCount: navigationViewModel.badgeCounts[tab],
                        action: {
                            withAnimation(.easeInOut(duration: TaskFlowAnimation.medium)) {
                                navigationViewModel.selectedTab = tab
                                onTabSelected(tab)
                            }
                        }
                    )
                }

                Spacer()
            }
            .padding(.vertical, TaskFlowSpacing.large)
        } detail: {
            content(navigationViewModel.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var tabView: some View {
        TabView(selection: $navigationViewModel.selectedTab) {
            ForEach(MainNavigationTab.allCases) { tab in
                content(tab)
                    .tabItem {
                        SwiftUI.Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .onChange(of: navigationViewModel.selectedTab) { _, newValue in
            onTabSelected(newValue)
        }
    }
}

// MARK: - Sidebar Navigation Item
struct SidebarNavigationItem: View {
    let tab: MainNavigationTab
    let isSelected: Bool
    let badgeCount: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TaskFlowSpacing.medium) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? TaskFlowColors.primary : TaskFlowColors.textSecondary)
                    .frame(width: 24)

                Text(tab.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? TaskFlowColors.textPrimary : TaskFlowColors.textSecondary)

                Spacer()

                if let badgeCount = badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .padding(.horizontal, 6)
                        .background(TaskFlowColors.error)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, TaskFlowSpacing.large)
            .padding(.vertical, TaskFlowSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: TaskFlowRadius.medium)
                    .fill(isSelected ? TaskFlowColors.primary.opacity(0.1) : Color.clear)
            )
            .padding(.horizontal, TaskFlowSpacing.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview("Top Navigation Bar") {
    VStack {
        MainNavigationBar(
            viewModel: MainNavigationViewModel(),
            onTabSelected: { _ in }
        )

        Spacer()
    }
}

#Preview("Bottom Tab Bar") {
    VStack {
        Spacer()

        MainNavigationBar(
            viewModel: MainNavigationViewModel(),
            onTabSelected: { _ in }
        )
    }
}

