import SwiftUI

// MARK: - Personal Records Tab
struct ProgressRecordsView: View {
    let records: [PersonalRecord]
    @State private var selectedRecord: PersonalRecord?

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    pinnedTopRecord
                    recordsGrid
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .sheet(item: $selectedRecord) { record in
                PRDetailSheet(record: record)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundStyle(TFTheme.accentYellow.opacity(0.4))
            Text("No Personal Records Yet")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(TFTheme.textPrimary)
            Text("Complete workouts to start building\nyour personal records.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Featured top PR
    private var pinnedTopRecord: some View {
        let pr = records.first!
        return Button { selectedRecord = pr } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [pr.color.opacity(0.55), pr.color.opacity(0.20)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(pr.color.opacity(0.35), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Latest PR", systemImage: "trophy.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(pr.color)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pr.color.opacity(0.20))
                            .clipShape(Capsule())
                        Spacer()
                        Image(systemName: pr.icon)
                            .font(.system(size: 30))
                            .foregroundStyle(pr.color.opacity(0.50))
                    }

                    Text(pr.value)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(TFTheme.textPrimary)

                    HStack(spacing: 8) {
                        Text(pr.event)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFTheme.textPrimary)
                        if let imp = pr.improvement {
                            Text(imp)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TFTheme.accentGreen)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(TFTheme.accentGreen.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    }
                    Text(pr.detail)
                        .font(.caption)
                        .foregroundStyle(TFTheme.textSecondary)
                }
                .padding(20)
            }
            .frame(height: 170)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Records Grid
    private var recordsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(records.dropFirst()) { record in
                Button { selectedRecord = record } label: {
                    PRCardView(record: record)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - PR Card
struct PRCardView: View {
    let record: PersonalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: record.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(record.color)
                Spacer()
                if let imp = record.improvement {
                    Text(imp)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TFTheme.accentGreen)
                }
            }
            Text(record.value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
            Text(record.event)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TFTheme.textSecondary)
            Text(record.detail)
                .font(.system(size: 10))
                .foregroundStyle(TFTheme.textTertiary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(record.color.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(record.color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - PR Detail Sheet
struct PRDetailSheet: View {
    let record: PersonalRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        heroBanner
                        comparisonCard
                        contextCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle(record.event)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(record.color)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
    }

    private var heroBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [record.color.opacity(0.45), record.color.opacity(0.15)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            VStack(spacing: 6) {
                Image(systemName: record.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(record.color)
                Text(record.value)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(record.event + " Personal Record")
                    .font(.headline)
                    .foregroundStyle(TFTheme.textSecondary)
                Text(record.detail)
                    .font(.caption)
                    .foregroundStyle(TFTheme.textTertiary)
            }
            .padding(28)
        }
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Improvement")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
            HStack(spacing: 0) {
                statPill(title: "Previous", value: record.prevValue ?? "—", color: TFTheme.textTertiary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(TFTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                statPill(title: "Current PR", value: record.value, color: record.color)
            }
            if let imp = record.improvement {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TFTheme.accentGreen)
                    Text("Improved by \(imp)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TFTheme.accentGreen)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What's Next")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
            Text("Keep building fitness with consistent Zone 2 work and weekly long efforts. Your next target should be achievable within 4–6 weeks of focused training.")
                .font(.system(size: 13))
                .foregroundStyle(TFTheme.textPrimary)
                .lineSpacing(4)
        }
        .padding(16)
        .glassCard()
    }
}
