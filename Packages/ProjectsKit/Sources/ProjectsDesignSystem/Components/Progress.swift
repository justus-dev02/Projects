import SwiftUI

/// A circular progress indicator with the percentage in the middle.
public struct TFProgressRing: View {
    let progress: Double
    let tint: Color
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var lineWidth: CGFloat = 5

    public init(progress: Double, tint: Color = TFColor.accent) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
        .animation(.smooth, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress", bundle: .module))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

/// A slim horizontal progress bar.
public struct TFProgressBar: View {
    let progress: Double
    let tint: Color

    public init(progress: Double, tint: Color = TFColor.accent) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule().fill(tint).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 6)
        .animation(.smooth, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress", bundle: .module))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}
