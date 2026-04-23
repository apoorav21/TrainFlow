import SwiftUI

// MARK: - Ring View (kept for potential future use)
struct RingView: View {
    let progress: Double
    let ringColor: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        ZStack {
            Circle().stroke(ringColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
