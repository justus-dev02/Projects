//
//  TFProgressBar.swift
//  Projects
//
//  TaskFlow - Progress Bar Component
//

import SwiftUI

// MARK: - TFProgressBar
struct TFProgressBar: View {
    let progress: Double
    let height: CGFloat
    let showLabel: Bool
    let color: Color
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let showGradient: Bool
    
    init(
        progress: Double,
        height: CGFloat = 8,
        showLabel: Bool = false,
        color: Color = TaskFlowColors.primary,
        backgroundColor: Color = TaskFlowColors.background,
        cornerRadius: CGFloat = TaskFlowRadius.full,
        showGradient: Bool = false
    ) {
        self.progress = min(max(progress, 0), 100)
        self.height = height
        self.showLabel = showLabel
        self.color = color
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.showGradient = showGradient
    }
    
    var body: some View {
        VStack(spacing: TaskFlowSpacing.small) {
            if showLabel {
                HStack {
                    Spacer()
                    Text("\(Int(progress))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TaskFlowColors.textSecondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                        .frame(height: height)
                    
                    // Progress
                    Group {
                        if showGradient {
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.7), color]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            color
                        }
                    }
                    .frame(width: geometry.size.width * CGFloat(progress / 100), height: height)
                    .cornerRadius(cornerRadius)
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Circular Progress
struct TFCircularProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let backgroundColor: Color
    let showPercentage: Bool
    let icon: String?
    
    init(
        progress: Double,
        size: CGFloat = 80,
        lineWidth: CGFloat = 8,
        color: Color = TaskFlowColors.primary,
        backgroundColor: Color = TaskFlowColors.background,
        showPercentage: Bool = false,
        icon: String? = nil
    ) {
        self.progress = min(max(progress, 0), 100)
        self.size = size
        self.lineWidth = lineWidth
        self.color = color
        self.backgroundColor = backgroundColor
        self.showPercentage = showPercentage
        self.icon = icon
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(progress / 100))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Content
            VStack(spacing: 2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.25))
                        .foregroundColor(color)
                }
                
                if showPercentage {
                    Text("\(Int(progress))%")
                        .font(.system(size: size * 0.2, weight: .bold))
                        .foregroundColor(color)
                }
            }
        }
    }
}

// MARK: - Task Progress
struct TFTaskProgress: View {
    let completed: Int
    let total: Int
    let height: CGFloat
    let showLabel: Bool
    
    init(
        completed: Int,
        total: Int,
        height: CGFloat = 6,
        showLabel: Bool = false
    ) {
        self.completed = completed
        self.total = total
        self.height = height
        self.showLabel = showLabel
    }
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total) * 100
    }
    
    var body: some View {
        TFProgressBar(
            progress: progress,
            height: height,
            showLabel: showLabel,
            color: TaskFlowColors.success
        )
    }
}

// MARK: - Previews
#Preview("Progress Bar") {
    TFProgressBar(progress: 65, showLabel: true)
        .padding()
}

#Preview("Progress Bar - High") {
    TFProgressBar(progress: 85, height: 12, color: TaskFlowColors.success)
        .padding()
}

#Preview("Progress Bar - Gradient") {
    TFProgressBar(progress: 75, height: 10, showGradient: true)
        .padding()
}

#Preview("Circular Progress") {
    TFCircularProgress(progress: 65, size: 100, showPercentage: true)
        .padding()
}

#Preview("Circular Progress with Icon") {
    TFCircularProgress(progress: 80, size: 80, color: TaskFlowColors.success, icon: "checkmark")
        .padding()
}

#Preview("Task Progress") {
    TFTaskProgress(completed: 5, total: 8, showLabel: true)
        .padding()
}

#Preview("Multiple Progress Bars") {
    VStack(spacing: 16) {
        TFProgressBar(progress: 25, color: TaskFlowColors.error)
        TFProgressBar(progress: 50, color: TaskFlowColors.warning)
        TFProgressBar(progress: 75, color: TaskFlowColors.primary)
        TFProgressBar(progress: 100, color: TaskFlowColors.success)
    }
    .padding()
}
