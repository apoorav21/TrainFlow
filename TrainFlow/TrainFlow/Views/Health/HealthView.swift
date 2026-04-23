import SwiftUI

struct HealthView: View {
    @StateObject private var hk = HealthKitManager.shared
    @StateObject private var summaryVM = HealthSummaryViewModel()
    @State private var selectedTab = 0
    @State private var isRefreshing = false
    private let tabs = ["Overall", "Vitals", "Sleep", "Activity"]

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 0) {
                    headerBar
                    if !hk.isAuthorized {
                        authBanner
                    }
                    segmentPicker
                    TabView(selection: $selectedTab) {
                        OverallTabView(vm: summaryVM, hk: hk).tag(0)
                        VitalsTabView(heart: hk.heart, respiratory: hk.respiratory, summary: summaryVM.vitals).tag(1)
                        SleepTabView(nights: hk.sleepNights, summary: summaryVM.sleep).tag(2)
                        ActivityTabView(activity: hk.activity, summary: summaryVM.activity).tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                }
            }
            .navigationBarHidden(true)
            .task {
                await hk.requestAuthorization()
                await summaryVM.load()
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Health")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(hk.isAuthorized ? "Live HealthKit data" : "Sample data — grant access below")
                    .font(.caption)
                    .foregroundStyle(hk.isAuthorized ? TFTheme.textSecondary : TFTheme.accentYellow)
            }
            Spacer()
            Button {
                Task {
                    isRefreshing = true
                    await hk.fetchAll()
                    isRefreshing = false
                }
            } label: {
                Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(TFTheme.accentRed)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: isRefreshing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Auth banner
    private var authBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .foregroundStyle(TFTheme.accentRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("HealthKit Access")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TFTheme.textPrimary)
                Text("Tap to grant access for live metrics")
                    .font(.caption2)
                    .foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
            Button("Allow") {
                Task { await hk.requestAuthorization() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(TFTheme.bgPrimary)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(TFTheme.accentRed)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(TFTheme.accentRed.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Segment picker
    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = i }
                } label: {
                    VStack(spacing: 4) {
                        Text(tabs[i])
                            .font(.system(size: 13, weight: selectedTab == i ? .semibold : .regular))
                            .foregroundStyle(selectedTab == i ? TFTheme.textPrimary : TFTheme.textSecondary)
                        Capsule()
                            .fill(selectedTab == i ? TFTheme.accentRed : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.08))
        }
    }
}
