import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            TFTheme.bgPrimary.ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(TFTheme.accentOrange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(TFTheme.accentOrange)
                }
                Text("TrainFlow")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                ProgressView()
                    .tint(TFTheme.accentOrange)
                    .scaleEffect(1.2)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1
                    opacity = 1
                }
            }
        }
    }
}
