import SwiftUI

/// Icon and title with a small, fixed gap. Lists on iOS otherwise reserve a wide icon column for
/// labels, which pulls metadata such as "📅 Oct 15" apart.
public struct TFCompactLabelStyle: LabelStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: TFSpacing.xSmall) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == TFCompactLabelStyle {
    /// Icon and title with a small, fixed gap. See ``TFCompactLabelStyle``.
    public static var tfCompact: TFCompactLabelStyle { TFCompactLabelStyle() }
}
