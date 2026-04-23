import SwiftUI
import Charts

// MARK: - Health Metric Type
enum HealthMetricType: String, Identifiable {
    case heartRate = "Resting HR"
    case hrv = "HRV"
    case sleep = "Sleep"
    case vo2Max = "VO₂ Max"
    case steps = "Steps"
    case activeCalories = "Active Cal"
    case bloodOxygen = "Blood O₂"
    case respiratoryRate = "Resp. Rate"

    var id: String { rawValue }
}

// MARK: - Health Detail Sheet
struct HealthDetailSheet: View {
    let metric: HealthMetricType
    @ObservedObject var hk: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroSection
                        chartSection
                        insightSection
                        rangeSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(metric.rawValue)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(TFTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(metricColor)
                }
            }
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().fill(metricColor.opacity(0.15)).frame(width: 72, height: 72)
                    Image(systemName: metricIcon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(metricColor)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(metric.rawValue)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(TFTheme.textSecondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(currentValue)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(TFTheme.textPrimary)
                        Text(metricUnit)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(TFTheme.textSecondary)
                    }
                    statusBadge
                }
                Spacer()
            }
            statsRow
        }
        .padding(20)
        .glassCard()
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "7-Day Avg", value: sevenDayAvg)
            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
            statCell(label: "7-Day High", value: sevenDayHigh)
            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
            statCell(label: "7-Day Low", value: sevenDayLow)
        }
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textPrimary)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Chart
    @ViewBuilder
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("14-Day Trend")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)

            let data = chartData
            if data.isEmpty {
                Text("No historical data available yet.")
                    .font(.caption).foregroundStyle(TFTheme.textTertiary)
                    .frame(height: 140)
            } else {
                Chart(data) { pt in
                    AreaMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                        .foregroundStyle(LinearGradient(
                            colors: [metricColor.opacity(0.4), .clear],
                            startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                        .foregroundStyle(metricColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    PointMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                        .foregroundStyle(metricColor)
                        .symbolSize(40)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) {
                        AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                            .foregroundStyle(TFTheme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel().foregroundStyle(TFTheme.textTertiary)
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Insights
    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Insights", systemImage: "lightbulb.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.accentYellow)
            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(metricColor).frame(width: 6, height: 6).padding(.top, 6)
                    Text(insight)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(TFTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Range
    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Healthy Range", systemImage: "chart.bar.fill")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textSecondary)
            healthRangeBar
        }
        .padding(18)
        .glassCard()
    }

    private var healthRangeBar: some View {
        let (low, high, current) = rangeValues
        let fraction = max(0, min(1, (current - low) / max(1, high - low)))
        return VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [TFTheme.accentRed, TFTheme.accentYellow, TFTheme.accentGreen, TFTheme.accentYellow, TFTheme.accentRed],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(height: 12)
                    Circle().fill(.white).shadow(color: .black.opacity(0.4), radius: 3)
                        .frame(width: 18, height: 18)
                        .offset(x: max(0, CGFloat(fraction) * (geo.size.width - 18)))
                }
            }
            .frame(height: 18)
            HStack {
                Text(formatRange(low)).font(.caption2).foregroundStyle(TFTheme.textTertiary)
                Spacer()
                Text("Optimal").font(.caption2.weight(.semibold)).foregroundStyle(TFTheme.accentGreen)
                Spacer()
                Text(formatRange(high)).font(.caption2).foregroundStyle(TFTheme.textTertiary)
            }
            HStack {
                Text("Healthy range: \(formatRange(low))–\(formatRange(high)) \(metricUnit)")
                    .font(.caption).foregroundStyle(TFTheme.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Computed Properties
    private var metricColor: Color {
        switch metric {
        case .heartRate: return TFTheme.accentRed
        case .hrv: return TFTheme.accentPurple
        case .sleep: return TFTheme.accentBlue
        case .vo2Max: return TFTheme.accentCyan
        case .steps: return TFTheme.accentGreen
        case .activeCalories: return TFTheme.accentOrange
        case .bloodOxygen: return TFTheme.accentBlue
        case .respiratoryRate: return TFTheme.accentCyan
        }
    }

    private var metricIcon: String {
        switch metric {
        case .heartRate: return "heart.fill"
        case .hrv: return "waveform.path.ecg"
        case .sleep: return "moon.fill"
        case .vo2Max: return "lungs.fill"
        case .steps: return "figure.walk"
        case .activeCalories: return "flame.fill"
        case .bloodOxygen: return "drop.fill"
        case .respiratoryRate: return "wind"
        }
    }

    private var metricUnit: String {
        switch metric {
        case .heartRate: return "bpm"
        case .hrv: return "ms"
        case .sleep: return "hrs"
        case .vo2Max: return "mL/kg·min"
        case .steps: return "steps"
        case .activeCalories: return "kcal"
        case .bloodOxygen: return "%"
        case .respiratoryRate: return "br/min"
        }
    }

    private var currentValue: String {
        switch metric {
        case .heartRate: return hk.heart.restingHR > 0 ? "\(hk.heart.restingHR)" : "62"
        case .hrv: return hk.heart.hrv > 0 ? String(format: "%.0f", hk.heart.hrv) : "48"
        case .sleep:
            let hrs = hk.sleepNights.last?.totalHours ?? 7.4
            return String(format: "%.1f", hrs)
        case .vo2Max: return hk.heart.vo2Max > 0 ? String(format: "%.1f", hk.heart.vo2Max) : "46.2"
        case .steps: return hk.activity.steps > 0 ? "\(hk.activity.steps)" : "8,240"
        case .activeCalories: return hk.activity.activeCalories > 0 ? "\(hk.activity.activeCalories)" : "420"
        case .bloodOxygen: return hk.respiratory.bloodOxygen > 0 ? String(format: "%.0f", hk.respiratory.bloodOxygen) : "98"
        case .respiratoryRate: return hk.respiratory.respiratoryRate > 0 ? String(format: "%.1f", hk.respiratory.respiratoryRate) : "14.2"
        }
    }

    private var statusBadge: some View {
        let (text, color) = statusInfo
        return Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch metric {
        case .heartRate:
            let hr = hk.heart.restingHR > 0 ? hk.heart.restingHR : 62
            if hr < 60 { return ("Athlete Level", TFTheme.accentGreen) }
            if hr < 72 { return ("Normal", TFTheme.accentBlue) }
            return ("Elevated", TFTheme.accentOrange)
        case .hrv:
            let hrv = hk.heart.hrv > 0 ? hk.heart.hrv : 48
            if hrv > 55 { return ("Excellent", TFTheme.accentGreen) }
            if hrv > 35 { return ("Good", TFTheme.accentBlue) }
            return ("Low", TFTheme.accentOrange)
        case .sleep:
            let hrs = hk.sleepNights.last?.totalHours ?? 7.4
            if hrs >= 7 { return ("Optimal", TFTheme.accentGreen) }
            if hrs >= 6 { return ("Fair", TFTheme.accentYellow) }
            return ("Low", TFTheme.accentRed)
        case .vo2Max:
            let v = hk.heart.vo2Max > 0 ? hk.heart.vo2Max : 46.2
            if v >= 48 { return ("High Fitness", TFTheme.accentGreen) }
            if v >= 40 { return ("Above Average", TFTheme.accentBlue) }
            return ("Below Average", TFTheme.accentOrange)
        case .steps:
            let s = hk.activity.steps > 0 ? hk.activity.steps : 8240
            if s >= 10000 { return ("Goal Met", TFTheme.accentGreen) }
            if s >= 7500 { return ("Active", TFTheme.accentBlue) }
            return ("Below Goal", TFTheme.accentOrange)
        case .activeCalories:
            let c = hk.activity.activeCalories > 0 ? hk.activity.activeCalories : 420
            if c >= 500 { return ("Excellent", TFTheme.accentGreen) }
            if c >= 300 { return ("Good", TFTheme.accentBlue) }
            return ("Low", TFTheme.accentOrange)
        case .bloodOxygen:
            let o = hk.respiratory.bloodOxygen > 0 ? hk.respiratory.bloodOxygen : 98
            if o >= 97 { return ("Normal", TFTheme.accentGreen) }
            return ("Low", TFTheme.accentRed)
        case .respiratoryRate:
            return ("Normal", TFTheme.accentGreen)
        }
    }

    private var chartData: [HRVDataPoint] {
        switch metric {
        case .heartRate:
            return hk.heart.restingHRHistory.isEmpty ? HealthSampleData.makeRHRHistory() : hk.heart.restingHRHistory
        case .hrv:
            return hk.heart.hrvHistory.isEmpty ? HealthSampleData.makeHRVHistory() : hk.heart.hrvHistory
        case .sleep:
            return hk.sleepNights.map { HRVDataPoint(date: $0.date, value: $0.totalHours) }
        case .vo2Max:
            return HealthSampleData.makeVO2History(base: hk.heart.vo2Max > 0 ? hk.heart.vo2Max : 46.2)
        case .steps:
            return HealthSampleData.makeStepsHistory(base: Double(hk.activity.steps > 0 ? hk.activity.steps : 8240))
        case .activeCalories:
            return HealthSampleData.makeCaloriesHistory(base: Double(hk.activity.activeCalories > 0 ? hk.activity.activeCalories : 420))
        case .bloodOxygen, .respiratoryRate:
            return HealthSampleData.makeBloodOxygenHistory()
        }
    }

    private var sevenDayAvg: String {
        let data = chartData.suffix(7)
        guard !data.isEmpty else { return "--" }
        let avg = data.map(\.value).reduce(0, +) / Double(data.count)
        return formatValue(avg)
    }

    private var sevenDayHigh: String {
        let data = chartData.suffix(7)
        guard let high = data.map(\.value).max() else { return "--" }
        return formatValue(high)
    }

    private var sevenDayLow: String {
        let data = chartData.suffix(7)
        guard let low = data.map(\.value).min() else { return "--" }
        return formatValue(low)
    }

    private func formatValue(_ v: Double) -> String {
        switch metric {
        case .heartRate, .steps: return "\(Int(v))"
        case .sleep: return String(format: "%.1f", v)
        case .vo2Max: return String(format: "%.1f", v)
        case .activeCalories: return "\(Int(v))"
        default: return String(format: "%.1f", v)
        }
    }

    private var insights: [String] {
        switch metric {
        case .heartRate:
            return [
                "A lower resting heart rate generally indicates better cardiovascular fitness and efficient heart function.",
                "Resting HR between 60–72 bpm is considered healthy for most adults.",
                "Consistent aerobic training typically lowers resting HR by 5–10 bpm over 3 months."
            ]
        case .hrv:
            return [
                "HRV reflects your autonomic nervous system balance — higher values indicate better recovery readiness.",
                "HRV naturally fluctuates daily. A sustained downward trend may signal overtraining or illness.",
                "Sleep quality, hydration, and stress all significantly affect your HRV."
            ]
        case .sleep:
            return [
                "Adults generally need 7–9 hours of quality sleep for optimal recovery and performance.",
                "Deep sleep (slow-wave) is critical for muscle repair and growth hormone release.",
                "REM sleep supports memory consolidation and mental recovery from hard training days."
            ]
        case .vo2Max:
            return [
                "VO₂ Max is one of the strongest predictors of long-term cardiovascular health and longevity.",
                "Interval training and long aerobic sessions are most effective at improving VO₂ Max.",
                "A 1 mL/kg/min improvement in VO₂ Max roughly correlates with a 1–2% performance improvement."
            ]
        case .steps:
            return [
                "10,000 steps/day is a widely cited target, but benefits are seen from as few as 7,500 steps.",
                "Regular walking improves insulin sensitivity, mood, and cardiovascular health.",
                "Try taking short walks after meals to improve blood sugar regulation."
            ]
        case .activeCalories:
            return [
                "Active calories reflect energy burned through intentional movement and exercise.",
                "Your active calorie goal should align with your training load and body composition goals.",
                "Combining cardio and strength work typically maximises daily active calorie burn."
            ]
        case .bloodOxygen:
            return [
                "Normal blood oxygen (SpO₂) is 95–100%. Below 92% warrants medical attention.",
                "SpO₂ may temporarily dip during intense exercise or at high altitude.",
                "Consistent low readings at rest should be discussed with your doctor."
            ]
        case .respiratoryRate:
            return [
                "A normal resting respiratory rate is 12–20 breaths per minute for adults.",
                "Athletes often have lower resting respiratory rates due to greater breathing efficiency.",
                "An elevated rate during rest can indicate stress, fever, or respiratory illness."
            ]
        }
    }

    private var rangeValues: (Double, Double, Double) {
        switch metric {
        case .heartRate:
            return (50, 80, Double(hk.heart.restingHR > 0 ? hk.heart.restingHR : 62))
        case .hrv:
            return (20, 80, hk.heart.hrv > 0 ? hk.heart.hrv : 48)
        case .sleep:
            return (5, 9, hk.sleepNights.last?.totalHours ?? 7.4)
        case .vo2Max:
            return (25, 65, hk.heart.vo2Max > 0 ? hk.heart.vo2Max : 46.2)
        case .steps:
            return (0, 15000, Double(hk.activity.steps > 0 ? hk.activity.steps : 8240))
        case .activeCalories:
            return (0, 800, Double(hk.activity.activeCalories > 0 ? hk.activity.activeCalories : 420))
        case .bloodOxygen:
            return (92, 100, hk.respiratory.bloodOxygen > 0 ? hk.respiratory.bloodOxygen : 98)
        case .respiratoryRate:
            return (10, 25, hk.respiratory.respiratoryRate > 0 ? hk.respiratory.respiratoryRate : 14.2)
        }
    }

    private func formatRange(_ v: Double) -> String {
        switch metric {
        case .steps, .activeCalories, .heartRate: return "\(Int(v))"
        case .sleep, .vo2Max, .respiratoryRate: return String(format: "%.0f", v)
        default: return String(format: "%.0f", v)
        }
    }
}
