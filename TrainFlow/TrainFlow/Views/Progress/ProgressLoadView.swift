import SwiftUI
import Charts

// MARK: - Training Load Tab
struct ProgressLoadView: View {
    let loads: [WeeklyLoad]
    @State private var selectedWeek: WeeklyLoad?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                fitnessChartCard
                tsbCard
                weekStatsGrid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Fitness Chart
    private var fitnessChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Fitness & Fatigue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("CTL = fitness · ATL = fatigue · 12-week view")
                    .font(.caption2)
                    .foregroundStyle(TFTheme.textSecondary)
            }
            Chart {
                ForEach(loads) { w in
                    LineMark(
                        x: .value("Week", w.label),
                        y: .value("CTL", w.chronicLoad)
                    )
                    .foregroundStyle(TFTheme.accentBlue)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .symbolSize(22)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Week", w.label),
                        y: .value("CTL", w.chronicLoad)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [TFTheme.accentBlue.opacity(0.25), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Week", w.label),
                        y: .value("ATL", w.acuteLoad)
                    )
                    .foregroundStyle(TFTheme.accentOrange)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 3)) { val in
                    AxisValueLabel {
                        if let s = val.as(String.self) {
                            Text(s).font(.system(size: 9))
                                .foregroundStyle(TFTheme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { val in
                    AxisValueLabel {
                        if let d = val.as(Double.self) {
                            Text("\(Int(d))").font(.system(size: 10))
                                .foregroundStyle(TFTheme.textTertiary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.05))
                }
            }
            .frame(height: 160)

            legendRow
        }
        .padding(16)
        .glassCard()
    }

    private var legendRow: some View {
        HStack(spacing: 20) {
            legendItem(color: TFTheme.accentBlue, label: "Fitness (CTL)", dashed: false)
            legendItem(color: TFTheme.accentOrange, label: "Fatigue (ATL)", dashed: true)
            Spacer()
            if let last = loads.last {
                VStack(alignment: .trailing, spacing: 1) {
                    let form = last.tsb
                    Text(form >= 0 ? "Fresh +\(Int(form))" : "Tired \(Int(form))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(form >= 0 ? TFTheme.accentGreen : TFTheme.accentRed)
                    Text("Current Form")
                        .font(.system(size: 9))
                        .foregroundStyle(TFTheme.textTertiary)
                }
            }
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            if dashed {
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(color).frame(width: 4, height: 2)
                    }
                }
            } else {
                Rectangle().fill(color).frame(width: 14, height: 2)
            }
            Text(label).font(.system(size: 10)).foregroundStyle(TFTheme.textSecondary)
        }
    }

    // MARK: - TSB Card
    private var tsbCard: some View {
        let recentLoads = Array(loads.suffix(8))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Distance (km)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TFTheme.textPrimary)
            Chart(recentLoads) { w in
                BarMark(
                    x: .value("Week", w.label),
                    y: .value("km", w.distanceKm)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [TFTheme.accentOrange, TFTheme.accentRed.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .cornerRadius(5)
            }
            .chartXAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let s = val.as(String.self) {
                            Text(String(s.prefix(6))).font(.system(size: 9))
                                .foregroundStyle(TFTheme.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { val in
                    AxisValueLabel {
                        if let d = val.as(Double.self) {
                            Text("\(Int(d))").font(.system(size: 10))
                                .foregroundStyle(TFTheme.textTertiary)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.05))
                }
            }
            .frame(height: 130)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Week Stats Grid
    private var weekStatsGrid: some View {
        guard let cur = loads.last, let prev = loads.dropLast().last else {
            return AnyView(EmptyView())
        }
        let items: [(String, String, String, Color)] = [
            ("Sessions", "\(cur.sessionCount)", delta(cur.sessionCount, prev.sessionCount, higher: true), TFTheme.accentBlue),
            ("Distance", "\(Int(cur.distanceKm)) km", delta(Int(cur.distanceKm), Int(prev.distanceKm), higher: true), TFTheme.accentOrange),
            ("Duration", "\(cur.durationMin) min", delta(cur.durationMin, prev.durationMin, higher: true), TFTheme.accentPurple),
            ("Fitness", "\(Int(cur.chronicLoad))", delta(Int(cur.chronicLoad), Int(prev.chronicLoad), higher: true), TFTheme.accentGreen),
        ]
        return AnyView(
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.system(size: 11))
                            .foregroundStyle(TFTheme.textSecondary)
                        Text(item.1)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(TFTheme.textPrimary)
                        Text(item.2)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(item.3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard(cornerRadius: 16)
                }
            }
        )
    }

    private func delta(_ cur: Int, _ prev: Int, higher: Bool) -> String {
        let diff = cur - prev
        if diff == 0 { return "— same as last week" }
        let sign = diff > 0 ? "↑" : "↓"
        let good = higher ? diff > 0 : diff < 0
        let _ = good
        return "\(sign) \(abs(diff)) vs last week"
    }
}
