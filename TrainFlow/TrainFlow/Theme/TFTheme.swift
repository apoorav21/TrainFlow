import SwiftUI
import UIKit

enum TFTheme {
    // MARK: - Adaptive Backgrounds
    // Dark:  deep navy-black  |  Light: true white / soft grey
    static let bgPrimary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.07, blue: 0.11, alpha: 1)
            : UIColor.systemBackground
    })

    static let bgSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.11, blue: 0.16, alpha: 1)
            : UIColor.secondarySystemBackground
    })

    static let bgCard = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.14, blue: 0.20, alpha: 1)
            : UIColor.systemBackground
    })

    // MARK: - Adaptive Text
    static let textPrimary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.white
            : UIColor.label
    })

    static let textSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.60, alpha: 1)
            : UIColor.secondaryLabel
    })

    static let textTertiary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(white: 0.40, alpha: 1)
            : UIColor.tertiaryLabel
    })

    // MARK: - Accent (same in both modes — vibrant against any bg)
    static let accentOrange = Color(red: 1.0,  green: 0.55, blue: 0.20)
    static let accentBlue   = Color(red: 0.25, green: 0.60, blue: 1.0)
    static let accentPurple = Color(red: 0.65, green: 0.35, blue: 1.0)
    static let accentGreen  = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let accentRed    = Color(red: 1.0,  green: 0.35, blue: 0.40)
    static let accentCyan   = Color(red: 0.30, green: 0.80, blue: 0.95)
    static let accentYellow = Color(red: 1.0,  green: 0.82, blue: 0.30)

    // MARK: - HR Zones
    static let zone1 = Color(red: 0.55, green: 0.80, blue: 0.95)
    static let zone2 = Color(red: 0.30, green: 0.85, blue: 0.55)
    static let zone3 = Color(red: 1.0,  green: 0.82, blue: 0.30)
    static let zone4 = Color(red: 1.0,  green: 0.55, blue: 0.20)
    static let zone5 = Color(red: 1.0,  green: 0.35, blue: 0.40)

    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [accentOrange.opacity(0.7), accentPurple.opacity(0.5)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cardGradient = LinearGradient(
        colors: [bgCard, bgCard.opacity(0.6)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Adaptive Glass Card Modifier
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                colorScheme == .dark
                    ? AnyView(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.5))
                            .background(TFTheme.bgCard.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
                    : AnyView(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
