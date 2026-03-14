//
//  NotificationsView.swift
//  Projects
//
//  TaskFlow - Notifications View
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Notifications View Model
@MainActor
class NotificationsViewModel: ObservableObject {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NotificationModel.createdAt, order: .reverse) private var notifications: [NotificationModel]
    
    @Published var filteredNotifications: [NotificationModel] = []
    @Published var showingUnreadOnly = false
    @Published var isLoading = false
    
    private let authService: AuthService

    init(authService: AuthService? = nil) {
        self.authService = authService ?? AuthService.shared
    }
    
    func loadNotifications() {
        if showingUnreadOnly {
            filteredNotifications = notifications.filter { !$0.isRead }
        } else {
            filteredNotifications = notifications
        }
    }
    
    func markAsRead(_ notification: NotificationModel) {
        notification.isRead = true
        notification.readAt = Date()
    }
    
    func markAllAsRead() {
        for notification in notifications where !notification.isRead {
            markAsRead(notification)
        }
    }
    
    func deleteNotification(_ notification: NotificationModel) {
        modelContext.delete(notification)
    }
    
    func clearAllNotifications() {
        for notification in notifications {
            modelContext.delete(notification)
        }
    }
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
}

// MARK: - Notifications View
struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.filteredNotifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: {
                            viewModel.showingUnreadOnly.toggle()
                            viewModel.loadNotifications()
                        }) {
                            SwiftUI.Label(
                                viewModel.showingUnreadOnly ? "Show All" : "Show Unread",
                                systemImage: "eye"
                            )
                        }
                        
                        Button(action: {
                            viewModel.markAllAsRead()
                        }) {
                            SwiftUI.Label("Mark All Read", systemImage: "checkmark.circle")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            viewModel.clearAllNotifications()
                        }) {
                            SwiftUI.Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task {
                viewModel.loadNotifications()
            }
        }
    }

    // MARK: - Notification List
    private var notificationList: some View {
        List {
            ForEach(viewModel.filteredNotifications, id: \.id) { notification in
                NotificationRow(
                    notification: notification,
                    onMarkRead: {
                        viewModel.markAsRead(notification)
                    },
                    onDelete: {
                        viewModel.deleteNotification(notification)
                    }
                )
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.deleteNotification(notification)
                    } label: {
                        SwiftUI.Label("Delete", systemImage: "trash")
                    }

                    if !notification.isRead {
                        Button {
                            viewModel.markAsRead(notification)
                        } label: {
                            SwiftUI.Label("Mark Read", systemImage: "checkmark.circle")
                        }
                        .tint(TaskFlowColors.primary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        TFEmptyStateCard(
            icon: "bell",
            title: "No Notifications",
            message: viewModel.showingUnreadOnly
                ? "You have no unread notifications."
                : "You're all caught up!",
            actionTitle: nil
        )
        .padding()
    }
}

// MARK: - Notification Row
struct NotificationRow: View {
    let notification: NotificationModel
    let onMarkRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: TaskFlowSpacing.medium) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: notificationTypeColor).opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: notificationTypeIcon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: notificationTypeColor))
            }
            
            // Content
            VStack(alignment: .leading, spacing: TaskFlowSpacing.xs) {
                HStack {
                    Text(notification.title)
                        .font(.system(size: 14, weight: notification.isRead ? .regular : .semibold))
                        .foregroundColor(TaskFlowColors.textPrimary)
                    
                    Spacer()
                    
                    if !notification.isRead {
                        Circle()
                            .fill(TaskFlowColors.primary)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(notification.message)
                    .font(.system(size: 13))
                    .foregroundColor(TaskFlowColors.textSecondary)
                    .lineLimit(2)
                
                Text(formatDate(notification.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(TaskFlowColors.textTertiary)
            }
            
            Spacer()
        }
        .padding(.vertical, TaskFlowSpacing.small)
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
    
    private var notificationTypeIcon: String {
        NotificationModel.NotificationType(rawValue: notification.type)?.icon ?? "info.circle.fill"
    }
    
    private var notificationTypeColor: String {
        NotificationModel.NotificationType(rawValue: notification.type)?.color ?? "#2D5BFF"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Notification Badge
struct NotificationBadge: View {
    let count: Int
    
    var body: some View {
        Group {
            if count > 0 {
                Text("\(min(count, 99))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(TaskFlowColors.error)
                    .cornerRadius(TaskFlowRadius.full)
            }
        }
    }
}

// MARK: - Preview
#Preview("Notifications") {
    NotificationsView()
}

#Preview("Notification Row") {
    let notification = NotificationModel(
        title: "Task Assigned",
        message: "You were assigned to \"Design Homepage\"",
        type: "assignment"
    )
    return NotificationRow(
        notification: notification,
        onMarkRead: {},
        onDelete: {}
    )
    .padding()
}
