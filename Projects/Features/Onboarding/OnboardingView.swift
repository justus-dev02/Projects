import SwiftUI
import ProjectsData
import ProjectsDesignSystem

/// A short introduction on first launch. The app starts empty; reminder permission is requested
/// when the user continues.
struct OnboardingView: View {
    @Environment(AppDependencies.self) private var dependencies
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: TFSpacing.xLarge) {
            Spacer(minLength: TFSpacing.large)
            Image(systemName: "checklist")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(TFColor.accent.gradient)
                .accessibilityHidden(true)
            Text("Welcome to Projects")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: TFSpacing.large) {
                feature("rectangle.split.3x1", title: "Boards, lists, calendar and timeline", text: "See your projects the way that suits the moment.")
                feature("bell.badge", title: "Reminders that act", text: "Complete or snooze tasks right from the notification.")
                feature("lock.shield", title: "Private by design", text: "Your data stays on your device. No account, no tracking.")
            }
            .tfCard()
            .frame(maxWidth: 460)

            Spacer(minLength: TFSpacing.large)

            Button {
                finish()
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .accessibilityIdentifier("onboarding.start")
            .frame(maxWidth: 460)
        }
        .padding(TFSpacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TFColor.background)
        #if os(macOS)
        .frame(width: 560, height: 640)
        #endif
    }

    private func feature(_ symbol: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: TFSpacing.large) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(TFColor.accent)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TFSpacing.xxSmall) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func finish() {
        Task {
            if await dependencies.reminders.requestAuthorizationIfNeeded() {
                await dependencies.refreshPlatformState()
            }
        }
        onFinish()
    }
}
