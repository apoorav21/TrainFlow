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
        VStack(spacing: 0) {
            ZStack {
                // Outer glow layer
                Circle()
                    .trim(from: 0, to: CGFloat(vm.overallScore) / 100.0 * 0.75)
                    .stroke(scoreColor.opacity(0.3), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .blur(radius: 8)
                    .frame(width: 164, height: 164)
                    .animation(.spring(response: 0.9, dampingFraction: 0.75), value: vm.overallScore)

                // Background arc (270°, opens at bottom)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(135))
                    .frame(width: 164, height: 164)

                // Tick marks at 25 / 50 / 75
                ForEach([0.25, 0.50, 0.75], id: \.self) { pct in
                    Circle()
                        .trim(from: CGFloat(pct * 0.75) - 0.003, to: CGFloat(pct * 0.75) + 0.003)
                        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                        .rotationEffect(.degrees(135))
                        .frame(width: 164, height: 164)
                }

                // Filled arc with gradient
                Circle()
                    .trim(from: 0, to: max(CGFloat(vm.overallScore) / 100.0 * 0.75, 0.001))
                    .stroke(
                        LinearGradient(
                            colors: [scoreColor.opacity(0.7), scoreColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(135))
                    .frame(width: 164, height: 164)
                    .animation(.spring(response: 0.9, dampingFraction: 0.75), value: vm.overallScore)

                // Score number
                VStack(spacing: 0) {
                    Text("\(vm.overallScore)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(vm.overallScore > 0 ? scoreColor : TFTheme.textTertiary)
                        .shadow(color: scoreColor.opacity(0.4), radius: 8, x: 0, y: 0)
                        .animation(.spring(response: 0.5), value: vm.overallScore)
                    Text("out of 100")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(TFTheme.textTertiary)
                }
                .offset(y: 8)
            }
            .frame(height: 180)

            Spacer().frame(height: 4)

            Text("Overall Health Score")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)

            Spacer().frame(height: 10)

            // Score badge + rating scale
            HStack(spacing: 12) {
                Label(scoreLabel, systemImage: scoreBadgeIcon)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(scoreColor)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(scoreColor.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(scoreColor.opacity(0.25), lineWidth: 1))
            }

            Spacer().frame(height: 16)

            // Mini scale bar
            HStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { i in
                    let pct = Double(i) / 19.0
                    let filled = pct <= Double(vm.overallScore) / 100.0
                    Capsule()
                        .fill(filled ? scaleBarColor(pct: pct) : Color.white.opacity(0.06))
                        .frame(height: 4)
                    if i < 19 { Spacer().frame(width: 2) }
                }
            }
            .animation(.easeOut(duration: 0.6), value: vm.overallScore)

            HStack {
                Text("0").font(.system(size: 10)).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("50").font(.system(size: 10)).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("100").font(.system(size: 10)).foregroundStyle(TFTheme.textTertiary)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glassCard()
    }

    private func scaleBarColor(pct: Double) -> Color {
        if pct < 0.4 { return TFTheme.accentRed }
        if pct < 0.6 { return TFTheme.accentYellow }
        if pct < 0.8 { return TFTheme.accentBlue }
        return TFTheme.accentGreen
    }

    private var scoreColor: Color {
        switch vm.overallScore {
        case 80...100: return TFTheme.accentGreen
        case 60..<80:  return TFTheme.accentBlue
        case 40..<60:  return TFTheme.accentYellow
        default:       return TFTheme.accentRed
        }
    }

    private var scoreLabel: String {
        switch vm.overallScore {
        case 80...100: return "Excellent"
        case 60..<80:  return "Good"
        case 40..<60:  return "Fair"
        case 1..<40:   return "Needs Attention"
        default:       return "Loading…"
        }
    }

    private var scoreBadgeIcon: String {
        switch vm.overallScore {
        case 80...100: return "star.fill"
        case 60..<80:  return "checkmark.circle.fill"
        case 40..<60:  return "exclamationmark.circle.fill"
        case 1..<40:   return "arrow.up.heart.fill"
        default:       return "clock.fill"
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
