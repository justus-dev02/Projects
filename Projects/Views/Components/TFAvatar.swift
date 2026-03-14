//
//  TFAvatar.swift
//  Projects
//
//  TaskFlow - Avatar Component
//

import SwiftUI

// MARK: - Avatar Size
enum TFAvatarSize {
    case xSmall
    case small
    case medium
    case large
    case xLarge
    
    var size: CGFloat {
        switch self {
        case .xSmall: return 24
        case .small: return 32
        case .medium: return 40
        case .large: return 48
        case .xLarge: return 64
        }
    }
    
    var font: Font {
        switch self {
        case .xSmall: return .system(size: 10, weight: .semibold)
        case .small: return .system(size: 12, weight: .semibold)
        case .medium: return .system(size: 14, weight: .semibold)
        case .large: return .system(size: 18, weight: .semibold)
        case .xLarge: return .system(size: 24, weight: .semibold)
        }
    }
}

// MARK: - TFAvatar
struct TFAvatar: View {
    let name: String
    let colorHex: String?
    let imageUrl: String?
    let size: TFAvatarSize
    let showBorder: Bool
    let borderColor: Color
    
    init(
        name: String,
        colorHex: String? = nil,
        imageUrl: String? = nil,
        size: TFAvatarSize = .medium,
        showBorder: Bool = false,
        borderColor: Color = .white
    ) {
        self.name = name
        self.colorHex = colorHex
        self.imageUrl = imageUrl
        self.size = size
        self.showBorder = showBorder
        self.borderColor = borderColor
    }
    
    var body: some View {
        ZStack {
            // Avatar Circle
            Group {
                if let imageUrl = imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                            placeholderView
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .clipShape(Circle())
            .frame(width: size.size, height: size.size)
            
            // Border
            if showBorder {
                Circle()
                    .stroke(borderColor, lineWidth: 2)
                    .frame(width: size.size, height: size.size)
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
            
            Text(initials)
                .font(size.font)
                .foregroundColor(.white)
        }
    }
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1).uppercased() + components[1].prefix(1).uppercased())
        } else if let first = components.first {
            return String(first.prefix(2).uppercased())
        }
        return "?"
    }
    
    private var backgroundColor: Color {
        if let colorHex = colorHex {
            return Color(hex: colorHex)
        }
        // Generate consistent color from name
        let hash = name.hashValue
        let colors = TaskFlowColors.labelColors
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Avatar Stack
struct TFAvatarStack: View {
    let users: [(name: String, color: String?)]
    let size: TFAvatarSize
    let maxVisible: Int
    let overlap: CGFloat
    
    init(
        users: [(name: String, color: String?)],
        size: TFAvatarSize = .small,
        maxVisible: Int = 4,
        overlap: CGFloat = 12
    ) {
        self.users = users
        self.size = size
        self.maxVisible = maxVisible
        self.overlap = overlap
    }
    
    var body: some View {
        HStack(spacing: -overlap) {
            ForEach(users.prefix(maxVisible).indices, id: \.self) { index in
                TFAvatar(
                    name: users[index].name,
                    colorHex: users[index].color,
                    size: size,
                    showBorder: true
                )
                .offset(x: CGFloat(index) * -overlap)
            }
            
            if users.count > maxVisible {
                ZStack {
                    Circle()
                        .fill(TaskFlowColors.textTertiary.opacity(0.2))
                        .frame(width: size.size, height: size.size)
                    
                    Text("+\(users.count - maxVisible)")
                        .font(.system(size: size.size * 0.3, weight: .bold))
                        .foregroundColor(TaskFlowColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - User Avatar (from User model)
struct TFUserAvatar: View {
    let user: User
    let size: TFAvatarSize
    let showBorder: Bool
    
    init(
        user: User,
        size: TFAvatarSize = .medium,
        showBorder: Bool = false
    ) {
        self.user = user
        self.size = size
        self.showBorder = showBorder
    }
    
    var body: some View {
        TFAvatar(
            name: user.displayName,
            colorHex: user.avatarColor,
            size: size,
            showBorder: showBorder
        )
    }
}

// MARK: - Previews
#Preview("Small Avatar") {
    TFAvatar(name: "John Doe", size: .small)
        .padding()
}

#Preview("Medium Avatar") {
    TFAvatar(name: "John Doe", size: .medium)
        .padding()
}

#Preview("Large Avatar") {
    TFAvatar(name: "John Doe", size: .large)
        .padding()
}

#Preview("Avatar with Color") {
    TFAvatar(name: "Jane Smith", colorHex: "#FF6B6B", size: .medium)
        .padding()
}

#Preview("Avatar with Border") {
    TFAvatar(name: "John Doe", size: .medium, showBorder: true)
        .padding()
}

#Preview("Avatar Stack") {
    TFAvatarStack(
        users: [
            ("John Doe", "#FF6B6B"),
            ("Jane Smith", "#4ECDC4"),
            ("Bob Wilson", "#45B7D1"),
            ("Alice Brown", "#96CEB4"),
            ("Charlie Davis", "#FFEAA7")
        ],
        size: .medium,
        maxVisible: 3
    )
    .padding()
}

#Preview("User Avatar") {
    let user = User(email: "test@example.com", displayName: "Test User")
    TFUserAvatar(user: user, size: .large)
        .padding()
}
