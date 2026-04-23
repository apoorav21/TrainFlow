import SwiftUI
import Charts

struct VitalsTabView: View {
    let heart: HeartMetrics
    let respiratory: RespiratoryMetrics
    var summary: String? = nil

    @State private var expandedVO2 = false
    @State private var expandedHRV = false
    @State private var expandedRHR = false
    @State private var expandedOxygen = false
    @State private var expandedRespRate = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let s = summary { AISummaryBanner(text: s) }
                heartHeroCard
                vo2MaxCard
                hrvChartCard
                rhrChartCard
                oxygenCard
                respRateCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Heart Hero (always-visible summary strip)
    private var heartHeroCard: some View {
        HStack(spacing: 0) {
            heroStat(icon: "heart.fill", color: TFTheme.accentRed,
                     label: "Resting HR",
                     value: heart.restingHR > 0 ? "\(heart.restingHR)" : "--",
                     unit: "bpm", trend: heart.restingHRTrend, lowerBetter: true)
            divider
            heroStat(icon: "waveform.path.ecg", color: TFTheme.accentPurple,
                     label: "HRV",
                     value: heart.hrv > 0 ? String(format: "%.0f", heart.hrv) : "--",
                     unit: "ms", trend: heart.hrvTrend, lowerBetter: false)
            divider
            heroStat(icon: "figure.walk", color: TFTheme.accentBlue,
                     label: "Walk Avg HR",
                     value: heart.walkingAvgHR > 0 ? "\(heart.walkingAvgHR)" : "--",
                     unit: "bpm", trend: nil, lowerBetter: false)
        }
        .glassCard()
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1)
            .padding(.vertical, 14)
    }

    private func heroStat(icon: String, color: Color, label: String,
                           value: String, unit: String,
                           trend: Double?, lowerBetter: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
            Text(unit).font(.caption2).foregroundStyle(TFTheme.textSecondary)
            Text(label).font(.caption).foregroundStyle(TFTheme.textSecondary)
            if let t = trend, value != "--" {
                trendBadge(t, lowerIsBetter: lowerBetter)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func trendBadge(_ trend: Double, lowerIsBetter: Bool) -> some View {
        let improving = lowerIsBetter ? trend < 0 : trend > 0
        let arrow = trend < 0 ? "arrow.down.right" : "arrow.up.right"
        let color: Color = improving ? TFTheme.accentGreen : TFTheme.accentRed
        return HStack(spacing: 3) {
            Image(systemName: arrow).font(.system(size: 9, weight: .bold))
            Text(String(format: "%.1f", abs(trend))).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - VO2 Max Card (expandable)
    private var vo2MaxCard: some View {
        let hasData = heart.vo2Max > 0
        let vo2 = heart.vo2Max
        let (label, color) = hasData ? fitnessClassification(vo2) : ("No data", TFTheme.textTertiary)

        return VStack(alignment: .leading, spacing: 12) {
            // Header — always visible, tap to expand
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedVO2.toggle() } }) {
                HStack {
                    Image(systemName: "lungs.fill").foregroundStyle(TFTheme.accentCyan)
                    Text("Cardio Fitness (VO₂ Max)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TFTheme.textPrimary)
                    Spacer()
                    if hasData {
                        Text(label)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(color)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(color.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Image(systemName: expandedVO2 ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TFTheme.textTertiary)
                        .padding(.leading, 4)
                }
            }
            .buttonStyle(.plain)

            // Value row — always visible
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(hasData ? String(format: "%.1f", vo2) : "--")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(hasData ? TFTheme.textPrimary : TFTheme.textTertiary)
                Text("mL/kg·min")
                    .font(.subheadline)
                    .foregroundStyle(TFTheme.textSecondary)
            }

            if hasData { vo2RangeBar(vo2: vo2) }

            // Expandable insights
            if expandedVO2 {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentCyan,
                               text: "VO₂ max measures how efficiently your body uses oxygen during intense exercise. It's the gold standard for aerobic fitness.")
                    if hasData {
                        insightRow(icon: "target", color: color,
                                   text: "You're in the \(label.lowercased()) range. \(vo2Tip(vo2))")
                        insightRow(icon: "chart.line.uptrend.xyaxis", color: TFTheme.accentGreen,
                                   text: "To improve VO₂ max: add one weekly VO₂ max session — 4–6 × 3–5 min at 90–95% max HR with equal recovery.")
                    } else {
                        insightRow(icon: "exclamationmark.circle", color: TFTheme.accentYellow,
                                   text: "No VO₂ max data available. Apple Watch records this automatically during outdoor runs once you have enough data.")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func vo2Tip(_ vo2: Double) -> String {
        if vo2 < 34 { return "Focus on building your aerobic base with 3–4 easy Zone 2 runs per week." }
        if vo2 < 40 { return "Add one tempo run weekly to break into the above-average range." }
        if vo2 < 48 { return "Interval training will help push you into the high fitness tier." }
        return "Excellent! Maintain with consistent high-quality training."
    }

    private func fitnessClassification(_ vo2: Double) -> (String, Color) {
        if vo2 < 34 { return ("Low", TFTheme.accentRed) }
        if vo2 < 40 { return ("Below Avg", TFTheme.accentOrange) }
        if vo2 < 48 { return ("Above Avg", TFTheme.accentBlue) }
        return ("High", TFTheme.accentGreen)
    }

    private func vo2RangeBar(vo2: Double) -> some View {
        let zones: [(String, Color)] = [("Low", TFTheme.accentRed), ("Below Avg", TFTheme.accentOrange),
                                         ("Above Avg", TFTheme.accentBlue), ("High", TFTheme.accentGreen)]
        let fraction = min(max((vo2 - 20.0) / 40.0, 0), 1)
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(zones, id: \.0) { zone in
                            Capsule().fill(zone.1).frame(maxWidth: .infinity, maxHeight: 8)
                        }
                    }
                    Circle().fill(.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .offset(x: max(0, CGFloat(fraction) * (geo.size.width - 14)))
                }
            }
            .frame(height: 14)
            HStack {
                Text("20").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("34").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("40").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("48").font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("60+").font(.caption2).foregroundStyle(TFTheme.textTertiary)
            }
        }
    }

    // MARK: - HRV Chart (expandable)
    private var hrvChartCard: some View {
        let hasData = !heart.hrvHistory.isEmpty
        let data = hasData ? heart.hrvHistory : HealthSampleData.makeHRVHistory()

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedHRV.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg").foregroundStyle(TFTheme.accentPurple).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HRV — 14 Days").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Heart Rate Variability · Higher is better").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedHRV ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            Chart(data) { pt in
                AreaMark(x: .value("Date", pt.date), y: .value("HRV", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [TFTheme.accentPurple.opacity(0.45), .clear],
                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", pt.date), y: .value("HRV", pt.value))
                    .foregroundStyle(TFTheme.accentPurple)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Date", pt.date), y: .value("HRV", pt.value))
                    .foregroundStyle(TFTheme.accentPurple)
                    .symbolSize(35)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisValueLabel().foregroundStyle(TFTheme.textSecondary)
                }
            }
            .frame(height: 120)

            hrvInsightBanner

            if expandedHRV {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentPurple,
                               text: "HRV measures the variation in time between heartbeats. A higher HRV indicates better autonomic nervous system recovery and readiness to train.")
                    insightRow(icon: "bed.double.fill", color: TFTheme.accentBlue,
                               text: "HRV drops when you're stressed, underrecovered, or ill — even before you feel symptoms. Use it as your daily readiness gauge.")
                    insightRow(icon: "bolt.fill", color: TFTheme.accentGreen,
                               text: "Best HRV boosters: consistent sleep schedule, reduced alcohol, nasal breathing, and cold exposure. Even one poor night drops HRV 10–15%.")
                    if heart.hrv > 0 {
                        let readiness = heart.hrv > 50 ? "push hard" : heart.hrv > 40 ? "train moderately" : "focus on recovery"
                        insightRow(icon: "target", color: TFTheme.accentOrange,
                                   text: "Current HRV (\(String(format: "%.0f", heart.hrv))ms) suggests: \(readiness) today.")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private var hrvInsightBanner: some View {
        let trend = heart.hrvTrend
        let improving = trend > 0
        let icon = improving ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        let color = improving ? TFTheme.accentGreen : TFTheme.accentOrange
        let msg = improving
            ? "HRV trending up +\(String(format: "%.0f", abs(trend)))ms — recovery improving"
            : "HRV dipped \(String(format: "%.0f", abs(trend)))ms — consider extra rest"
        return HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.subheadline)
            Text(msg).font(.caption).foregroundStyle(TFTheme.textSecondary)
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Resting HR Chart (expandable)
    private var rhrChartCard: some View {
        let hasData = !heart.restingHRHistory.isEmpty
        let data = hasData ? heart.restingHRHistory : HealthSampleData.makeRHRHistory()

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedRHR.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill").foregroundStyle(TFTheme.accentRed).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Resting HR — 14 Days").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Lower is better for cardiovascular fitness").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: expandedRHR ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)

            Chart(data) { pt in
                AreaMark(x: .value("Date", pt.date), y: .value("HR", pt.value))
                    .foregroundStyle(LinearGradient(
                        colors: [TFTheme.accentRed.opacity(0.35), .clear],
                        startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", pt.date), y: .value("HR", pt.value))
                    .foregroundStyle(TFTheme.accentRed)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Date", pt.date), y: .value("HR", pt.value))
                    .foregroundStyle(TFTheme.accentRed)
                    .symbolSize(28)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisValueLabel().foregroundStyle(TFTheme.textSecondary)
                }
            }
            .frame(height: 100)

            if expandedRHR {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentRed,
                               text: "Resting HR is counted while you're still — ideally just after waking. Fit runners typically have an RHR of 40–60 bpm.")
                    if heart.restingHR > 0 {
                        let (rhrLabel, rhrColor) = rhrCategory(heart.restingHR)
                        insightRow(icon: "checkmark.circle.fill", color: rhrColor,
                                   text: "\(heart.restingHR) bpm — \(rhrLabel). \(rhrTip(heart.restingHR))")
                    }
                    insightRow(icon: "figure.run", color: TFTheme.accentOrange,
                               text: "Consistent aerobic training lowers RHR by 1 bpm per month on average. A sudden spike (>5 bpm) may indicate illness or overtraining.")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    private func rhrCategory(_ rhr: Int) -> (String, Color) {
        if rhr < 50 { return ("Athlete range", TFTheme.accentGreen) }
        if rhr < 60 { return ("Excellent", TFTheme.accentGreen) }
        if rhr < 70 { return ("Normal", TFTheme.accentBlue) }
        if rhr < 80 { return ("Above average", TFTheme.accentYellow) }
        return ("Elevated — consider more Zone 2 work", TFTheme.accentOrange)
    }

    private func rhrTip(_ rhr: Int) -> String {
        if rhr < 60 { return "Keep up the aerobic base — you're in great cardiovascular shape." }
        if rhr < 70 { return "3–4 Zone 2 runs per week will push this lower over 6–8 weeks." }
        return "Focus on building your aerobic base before adding high-intensity work."
    }

    // MARK: - Blood Oxygen (expandable)
    private var oxygenCard: some View {
        let hasData = respiratory.bloodOxygen > 0
        let value = hasData ? String(format: "%.0f%%", respiratory.bloodOxygen) : "--"
        let (oLabel, oColor): (String, Color) = hasData
            ? (respiratory.bloodOxygen >= 98 ? ("Optimal", TFTheme.accentGreen)
               : respiratory.bloodOxygen >= 95 ? ("Normal", TFTheme.accentBlue)
               : ("Low — consult a doctor", TFTheme.accentRed))
            : ("No data", TFTheme.textTertiary)

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedOxygen.toggle() } }) {
                HStack {
                    Image(systemName: "drop.fill").foregroundStyle(TFTheme.accentBlue).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Blood Oxygen (SpO₂)").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Oxygen saturation in your blood").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    if hasData {
                        Text(oLabel)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(oColor)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(oColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Image(systemName: expandedOxygen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary).padding(.leading, 4)
                }
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(hasData ? TFTheme.textPrimary : TFTheme.textTertiary)
                Text("SpO₂").font(.subheadline).foregroundStyle(TFTheme.textSecondary)
            }

            if expandedOxygen {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentBlue,
                               text: "SpO₂ measures the percentage of haemoglobin carrying oxygen. Healthy adults typically read 95–100%.")
                    insightRow(icon: "figure.run", color: TFTheme.accentOrange,
                               text: "During high-intensity exercise, SpO₂ can drop 2–4%. If it drops below 90% at rest, seek medical advice.")
                    if !hasData {
                        insightRow(icon: "exclamationmark.circle", color: TFTheme.accentYellow,
                                   text: "Requires Apple Watch Series 6+ with blood oxygen enabled in Settings → Health.")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Respiratory Rate (expandable)
    private var respRateCard: some View {
        let hasData = respiratory.respiratoryRate > 0
        let value = hasData ? String(format: "%.1f", respiratory.respiratoryRate) : "--"
        let (rLabel, rColor): (String, Color) = hasData
            ? (respiratory.respiratoryRate < 16 ? ("Low normal", TFTheme.accentBlue)
               : respiratory.respiratoryRate <= 20 ? ("Normal", TFTheme.accentGreen)
               : ("Elevated", TFTheme.accentYellow))
            : ("No data", TFTheme.textTertiary)

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.4)) { expandedRespRate.toggle() } }) {
                HStack {
                    Image(systemName: "wind").foregroundStyle(TFTheme.accentCyan).font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Respiratory Rate").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                        Text("Breaths per minute during sleep").font(.caption2).foregroundStyle(TFTheme.textSecondary)
                    }
                    Spacer()
                    if hasData {
                        Text(rLabel)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(rColor)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(rColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Image(systemName: expandedRespRate ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(TFTheme.textTertiary).padding(.leading, 4)
                }
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(hasData ? TFTheme.textPrimary : TFTheme.textTertiary)
                Text("br/min").font(.subheadline).foregroundStyle(TFTheme.textSecondary)
            }

            if expandedRespRate {
                Divider().background(Color.white.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    insightRow(icon: "info.circle.fill", color: TFTheme.accentCyan,
                               text: "Respiratory rate is measured during sleep by Apple Watch. Normal adults breathe 12–20 times per minute at rest.")
                    insightRow(icon: "exclamationmark.triangle.fill", color: TFTheme.accentYellow,
                               text: "A persistently elevated respiratory rate (>20 br/min) during sleep may indicate illness, stress, or sleep apnea worth discussing with a doctor.")
                    insightRow(icon: "figure.run", color: TFTheme.accentGreen,
                               text: "Trained athletes often have lower resting respiratory rates due to more efficient oxygen utilisation from aerobic training.")
                    if !hasData {
                        insightRow(icon: "exclamationmark.circle", color: TFTheme.accentYellow,
                                   text: "Requires Apple Watch. Ensure it's worn during sleep with sleep tracking enabled.")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Shared
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
}
