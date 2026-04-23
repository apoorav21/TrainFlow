import SwiftUI
import Charts

struct BodyTabView: View {
    let metrics: BodyMetrics

    @State private var expandedWeight = false
    @State private var expandedComposition = false
    @State private var expandedBMI = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                bodyHeroCard
                weightChartCard
                if metrics.bodyFat > 0 || metrics.leanMass > 0 { compositionCard }
                bmiCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Hero
    private var bodyHeroCard: some View {
        HStack(spacing: 0) {
            bodyHeroStat(icon: "scalemass.fill", color: TFTheme.accentBlue,
                         label: "Weight",
                         value: metrics.weight > 0 ? String(format: "%.1f", metrics.weight) : "--",
                         unit: "kg")
            Divider().frame(width: 1).background(Color.white.opacity(0.1)).padding(.vertical, 12)
            bodyHeroStat(icon: "figure.arms.open", color: TFTheme.accentOrange,
                         label: "Body Fat",
                         value: metrics.bodyFat > 0 ? String(format: "%.1f%%", metrics.bodyFat) : "--",
                         unit: "")
            Divider().frame(width: 1).background(Color.white.opacity(0.1)).padding(.vertical, 12)
            bodyHeroStat(icon: "bolt.fill", color: TFTheme.accentGreen,
                         label: "Lean Mass",
                         value: metrics.leanMass > 0 ? String(format: "%.1f", metrics.leanMass) : "--",
                         unit: "kg")
        }
        .glassCard()
    }

    private func bodyHeroStat(icon: String, color: Color, label: String, value: String, unit: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(value == "--" ? TFTheme.textTertiary : TFTheme.textPrimary)
            if !unit.isEmpty {
                Text(unit).font(.caption2).foregroundStyle(TFTheme.textSecondary)
            }
            Text(label).font(.caption).foregroundStyle(TFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Weight chart (expandable)
    private var weightChartCard: some View {
        let hasData = !metrics.weightHistory.isEmpty
        let history = metrics.weightHistory

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedWeight.toggle() } }) {
                HStack {
                    Image(systemName: "scalemass.fill").foregroundStyle(TFTheme.accentBlue).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Weight Trend — 14 Days")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text(hasData ? "Tap for insights" : "No data recorded yet")
                            .font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedWeight ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if hasData {
                let avg = history.reduce(0) { $0 + $1.value } / Double(history.count)
                Chart {
                    ForEach(history) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("kg", pt.value))
                            .foregroundStyle(TFTheme.accentBlue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        AreaMark(x: .value("Date", pt.date), y: .value("kg", pt.value))
                            .foregroundStyle(LinearGradient(
                                colors: [TFTheme.accentBlue.opacity(0.3), .clear],
                                startPoint: .top, endPoint: .bottom))
                        PointMark(x: .value("Date", pt.date), y: .value("kg", pt.value))
                            .foregroundStyle(TFTheme.accentBlue).symbolSize(25)
                    }
                    RuleMark(y: .value("Avg", avg))
                        .foregroundStyle(TFTheme.accentYellow.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .annotation(position: .trailing) {
                            Text("avg").font(.caption2).foregroundStyle(TFTheme.accentYellow)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                        AxisValueLabel().foregroundStyle(TFTheme.textSecondary)
                    }
                }
                .frame(height: 130)

                let first = history.first?.value ?? 0
                let last  = history.last?.value ?? 0
                let delta = last - first
                HStack {
                    Image(systemName: delta < 0 ? "arrow.down" : "arrow.up")
                    Text(String(format: "%.1f kg over 14 days", abs(delta)))
                }
                .font(.caption)
                .foregroundStyle(delta < 0 ? TFTheme.accentGreen : TFTheme.accentOrange)

                if expandedWeight {
                    Divider().background(Color.white.opacity(0.08))
                    VStack(alignment: .leading, spacing: 8) {
                        insightRow(icon: "info.circle.fill", color: TFTheme.accentBlue,
                                   text: "Body weight fluctuates 1–2 kg daily due to hydration, food, and glycogen. Focus on the 7-day rolling trend, not single-day readings.")
                        insightRow(icon: "fork.knife", color: TFTheme.accentOrange,
                                   text: "For runners, weight loss during a training block can reduce power output. Aim for gradual changes (0.3–0.5 kg/week max) to protect performance.")
                        if abs(delta) < 0.5 {
                            insightRow(icon: "checkmark.circle.fill", color: TFTheme.accentGreen,
                                       text: "Weight is stable — good sign of consistent nutrition and hydration habits.")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                noDataView(message: "No weight data. Log your weight in the Health app or on a connected smart scale.")
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Body Composition (expandable, only shown if data exists)
    private var compositionCard: some View {
        let fat  = metrics.bodyFat
        let lean = metrics.leanMass
        let fatFrac  = CGFloat(fat / 100)
        let leanFrac = 1 - fatFrac

        return VStack(alignment: .leading, spacing: 14) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedComposition.toggle() } }) {
                HStack {
                    Image(systemName: "chart.pie.fill").foregroundStyle(TFTheme.accentPurple).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Body Composition").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Fat vs lean mass breakdown").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedComposition ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TFTheme.accentGreen)
                        .frame(width: max(geo.size.width * leanFrac - 1, 0))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(TFTheme.accentOrange)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 18)

            HStack {
                legendDot(TFTheme.accentGreen,
                          label: lean > 0 ? String(format: "Lean %.1f kg (%.0f%%)", lean, (1 - fat/100)*100) : String(format: "Lean %.0f%%", (1 - fat/100)*100))
                Spacer()
                legendDot(TFTheme.accentOrange, label: String(format: "Fat %.1f%%", fat))
            }

            if expandedComposition {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentPurple,
                               text: "Healthy body fat: men 6–24%, women 16–30%. For runners, lower body fat (within healthy range) improves running economy.")
                    let (bfLabel, bfColor) = bodyFatCategory(fat)
                    insightRow(icon: "target", color: bfColor,
                               text: "Your body fat (\(String(format: "%.1f", fat))%) is in the \(bfLabel) range.")
                    insightRow(icon: "dumbbell.fill", color: TFTheme.accentGreen,
                               text: "Strength training 2× per week preserves lean mass during calorie deficits and reduces injury risk.")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func bodyFatCategory(_ fat: Double) -> (String, Color) {
        // Using male ranges as default — ideally this would use biological sex from HealthKit
        if fat < 6  { return ("essential fat", TFTheme.accentBlue) }
        if fat < 14 { return ("athlete", TFTheme.accentGreen) }
        if fat < 18 { return ("fitness", TFTheme.accentGreen) }
        if fat < 25 { return ("acceptable", TFTheme.accentBlue) }
        return ("above average", TFTheme.accentYellow)
    }

    // MARK: - BMI Card (expandable)
    private var bmiCard: some View {
        let hasData = metrics.bmi > 0
        let bmi = metrics.bmi

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedBMI.toggle() } }) {
                HStack {
                    Image(systemName: "gauge.medium").foregroundStyle(TFTheme.accentYellow).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BMI").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Body Mass Index").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    if hasData {
                        Text(bmiCategory(bmi))
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(bmiColor(bmi))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(bmiColor(bmi).opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Image(systemName: expandedBMI ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary).padding(.leading, 4)
                }
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(hasData ? String(format: "%.1f", bmi) : "--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(hasData ? TFTheme.textPrimary : TFTheme.textTertiary)
                Text("kg/m²").font(.subheadline).foregroundStyle(TFTheme.textSecondary)
            }

            if hasData { bmiRangeBar(bmi: bmi) }

            if expandedBMI {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentYellow,
                               text: "BMI is a rough screening tool. It doesn't distinguish muscle from fat — a muscular runner may show 'overweight' BMI while having excellent body composition.")
                    if hasData {
                        insightRow(icon: "target", color: bmiColor(bmi),
                                   text: "For runners, body composition (fat %) is a more useful metric than BMI. Use both together for a complete picture.")
                    } else {
                        insightRow(icon: "exclamationmark.circle", color: TFTheme.accentYellow,
                                   text: "BMI requires weight and height. Add your height in the Health app to enable this metric.")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func bmiCategory(_ v: Double) -> String {
        if v < 18.5 { return "Underweight" }
        if v < 25   { return "Normal" }
        if v < 30   { return "Overweight" }
        return "Obese"
    }

    private func bmiColor(_ v: Double) -> Color {
        if v < 18.5 { return TFTheme.accentBlue }
        if v < 25   { return TFTheme.accentGreen }
        if v < 30   { return TFTheme.accentYellow }
        return TFTheme.accentRed
    }

    private func bmiRangeBar(bmi: Double) -> some View {
        let fraction = min(max((bmi - 15) / 25, 0), 1)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        colors: [TFTheme.accentBlue, TFTheme.accentGreen, TFTheme.accentYellow, TFTheme.accentRed],
                        startPoint: .leading, endPoint: .trailing)
                        .frame(height: 8).clipShape(Capsule())
                    Circle().fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: CGFloat(fraction) * (geo.size.width - 14))
                }
            }
            .frame(height: 14)
            HStack {
                Text("15").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("18.5").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("25").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("30").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("40").font(.caption2).foregroundStyle(TFTheme.textTertiary)
            }
        }
    }

    // MARK: - Shared helpers
    private func legendDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(TFTheme.textSecondary)
        }
    }

    private func insightRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)
                .padding(.top, 1)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func noDataView(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(TFTheme.textTertiary)
            Text(message).font(.caption).foregroundStyle(TFTheme.textTertiary)
        }
        .padding(.vertical, 8)
    }
}
