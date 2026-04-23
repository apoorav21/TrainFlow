import SwiftUI

struct PlaceholderEmptyState: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let buttonTitle: String

    var body: some View {
        VStack(spacing: 20) {
            iconCircle
            textContent
            actionButton
        }
        .padding(32)
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.3), color.opacity(0.05)],
                        center: .center, startRadius: 5, endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
            Image(systemName: icon)
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(color)
        }
    }

    private var textContent: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(TFTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var actionButton: some View {
        Text(buttonTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(color)
            .clipShape(Capsule())
    }
}
