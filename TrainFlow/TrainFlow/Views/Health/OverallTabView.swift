import SwiftUI

struct OverallTabView: View {
    @ObservedObject var vm: HealthSummaryViewModel
    let hk: HealthKitManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                scoreCard
                if vm.isLoading {
                    loadingCard
                } else if let s = vm.summary {
                    if let overall = s.overallSummary {
                        summaryCard(icon: "brain.head.profile.fill", color: TFTheme.accentPurple,
                                    title: "AI Analysis", text: overall)
                    }
                    if let rec = s.keyRecommendation {
                        summaryCard(icon: "star.fill", color: TFTheme.accentYellow,
                                    title: "Top Recommendation", text: rec)
                    }
                    sectionSummaryRow(icon: "heart.fill", color: TFTheme.accentRed,
                                      label: "Vitals", text: s.vitals)
                    sectionSummaryRow(icon: "moon.fill", color: TFTheme.accentPurple,
                                      label: "Sleep", text: s.sleep)
                    sectionSummaryRow(icon: "figure.run", color: TFTheme.accentOrange,
                                      label: "Activity", text: s.activity)
                } else {
                    emptyCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 14)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.overallScore) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                    .animation(.easeOut(duration: 0.8), value: vm.overallScore)
                VStack(spacing: 2) {
                    Text("\(vm.overallScore)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                    Text("/ 100").font(.caption).foregroundStyle(TFTheme.textTertiary)
                }
            }
            Text("Overall Health Score")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
            Text(scoreLabel)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(scoreColor)
                .padding(.horizontal, 14).padding(.vertical, 4)
                .background(scoreColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }

    private var scoreColor: Color {
        switch vm.overallScore {
        case 80...100: return TFTheme.accentGreen
        case 60..<80: return TFTheme.accentBlue
        case 40..<60: return TFTheme.accentYellow
        default: return TFTheme.accentRed
        }
    }

    private var scoreLabel: String {
        switch vm.overallScore {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        case 1..<40: return "Needs Attention"
        default: return "Loading..."
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(TFTheme.accentPurple)
            Text("Generating AI analysis…")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32))
                .foregroundStyle(TFTheme.textTertiary)
            Text("No analysis yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
            Text("Refresh to generate your daily AI health summary")
                .font(.caption)
                .foregroundStyle(TFTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    private func summaryCard(icon: String, color: Color, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.subheadline).foregroundStyle(color)
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
            }
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard()
    }

    private func sectionSummaryRow(icon: String, color: Color, label: String, text: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(text ?? "No data yet")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(text != nil ? TFTheme.textSecondary : TFTheme.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - AISummaryBanner

struct AISummaryBanner: View {
    let text: String
    @State private var expanded = false

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.35)) { expanded.toggle() } }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(TFTheme.accentPurple)
                    Text("Goggins' Analysis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TFTheme.accentPurple)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TFTheme.textTertiary)
                }
                if expanded {
                    Text(text)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text(text)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(TFTheme.textTertiary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .background(TFTheme.accentPurple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TFTheme.accentPurple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
