import SwiftUI
import Amplify

struct TodayView: View {
    @EnvironmentObject private var trainingVM: DynamicTrainingViewModel
    @EnvironmentObject private var auth: AuthService
    @StateObject var hk = HealthKitManager.shared

    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    todayPlanCard
                    upcomingWorkoutsSection
                    vitalStatsRow
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(TFTheme.bgPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("TrainFlow")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(TFTheme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(auth)
            }
            .sheet(item: $trainingVM.selectedDay) { day in
                WorkoutDayRemoteDetailView(day: day, vm: trainingVM)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(TFTheme.textSecondary)
            Text(dateString)
                .font(.system(size: 14))
                .foregroundColor(TFTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Today's Plan Card (from real plan)
    @ViewBuilder
    private var todayPlanCard: some View {
        if let today = trainingVM.todayWorkout {
            if today.isRestDay {
                restDayCard
            } else {
                TodayPlanWorkoutCard(day: today, vm: trainingVM)
            }
        } else if trainingVM.plan != nil {
            restDayCard
        } else {
            noPlanCard
        }
    }

    private var restDayCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TFTheme.accentCyan.opacity(0.15)).frame(width: 56, height: 56)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(TFTheme.accentCyan)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("REST DAY").font(.system(.caption2, design: .rounded, weight: .black)).foregroundStyle(TFTheme.accentCyan)
                Text("Recovery & Rest").font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                Text("Sleep well, hydrate, and prepare for tomorrow.").font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16).glassCard()
    }

    private var noPlanCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(TFTheme.accentOrange.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: "figure.run").font(.system(size: 22)).foregroundStyle(TFTheme.accentOrange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("No Training Plan").font(.system(.body, design: .rounded, weight: .bold)).foregroundStyle(TFTheme.textPrimary)
                    Text("Chat with your AI Coach to build a personalised plan.")
                        .font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                }
                Spacer()
            }
        }
        .padding(16).glassCard()
    }

    // MARK: - Upcoming Workouts Section
    private var upcomingWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(TFTheme.textPrimary)
                Spacer()
                if let plan = trainingVM.plan {
                    Text(plan.goalType)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(TFTheme.accentOrange)
                }
            }
            if trainingVM.currentWeekDays.isEmpty {
                Text("No workouts this week yet.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(TFTheme.textTertiary)
                    .padding(16).glassCard()
            } else {
                ForEach(trainingVM.currentWeekDays.filter { !$0.isRestDay }) { day in
                    TodayWeekDayRow(day: day, vm: trainingVM)
                        .onTapGesture { trainingVM.selectedDay = day }
                }
            }
        }
    }

    // MARK: - Helpers
    private var firstName: String {
        let name = auth.displayName
        if name.isEmpty { return "Athlete" }
        return String(name.split(separator: " ").first ?? Substring(name))
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning, \(firstName) 💪" }
        if hour < 17 { return "Good afternoon, \(firstName) 🔥" }
        return "Good evening, \(firstName) 🌙"
    }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // Top-right: settings button
    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gearshape")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TFTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
    }
}

// MARK: - Today Plan Workout Card
struct TodayPlanWorkoutCard: View {
    let day: RemoteWorkoutDay
    @ObservedObject var vm: DynamicTrainingViewModel
    @State private var showDetail = false
    private var color: Color { vm.dayTypeColor("\(day.type) \(day.dayType)") }

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("TODAY'S WORKOUT", systemImage: "bolt.fill")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(color)
                    Spacer()
                    if day.isCompleted {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(TFTheme.accentGreen)
                    } else {
                        Text(day.phase.uppercased())
                            .font(.system(size: 10, weight: .bold)).foregroundColor(TFTheme.accentYellow)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(TFTheme.accentYellow.opacity(0.15)).clipShape(Capsule())
                    }
                }
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(color.opacity(0.2)).frame(width: 56, height: 56)
                        Image(systemName: vm.dayTypeIcon("\(day.type) \(day.dayType)"))
                            .font(.system(size: 26, weight: .semibold)).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.title)
                            .font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white)
                        HStack(spacing: 8) {
                            Label(day.targetDuration, systemImage: "timer")
                            if let d = day.targetDistance { Label(d, systemImage: "figure.run") }
                        }
                        .font(.system(size: 13)).foregroundColor(TFTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(TFTheme.textTertiary)
                }
                Text(day.instructions)
                    .font(.system(.caption, design: .rounded)).foregroundColor(TFTheme.textSecondary)
                    .lineLimit(2)
            }
            .padding(18)
            .background(LinearGradient(colors: [color.opacity(0.22), TFTheme.bgCard.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            WorkoutDayRemoteDetailView(day: day, vm: vm)
        }
    }
}

// MARK: - Week Day Row
struct TodayWeekDayRow: View {
    let day: RemoteWorkoutDay
    @ObservedObject var vm: DynamicTrainingViewModel
    private var isToday: Bool { Calendar.current.isDate(vm.dayDate(day), inSameDayAs: Date()) }
    private var isPast: Bool { vm.dayDate(day) < Calendar.current.startOfDay(for: Date()) }
    private var color: Color { vm.dayTypeColor("\(day.type) \(day.dayType)") }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(isToday ? 0.25 : 0.1)).frame(width: 42, height: 42)
                Image(systemName: vm.dayTypeIcon("\(day.type) \(day.dayType)"))
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(day.title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(TFTheme.textPrimary)
                HStack(spacing: 6) {
                    Text(dayLabel).font(.system(.caption, design: .rounded)).foregroundStyle(isToday ? color : TFTheme.textTertiary)
                    Text("·").foregroundStyle(TFTheme.textTertiary)
                    Text(day.targetDuration).font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.textSecondary)
                }
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .glassCard(cornerRadius: 14)
        .overlay(isToday ? RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.4), lineWidth: 1) : nil)
    }

    private var dayLabel: String {
        if isToday { return "Today" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: vm.dayDate(day))
    }

    @ViewBuilder
    private var statusBadge: some View {
        if day.isCompleted {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(TFTheme.accentGreen)
        } else if isPast {
            Image(systemName: "xmark.circle").font(.system(size: 18)).foregroundStyle(TFTheme.accentRed.opacity(0.6))
        } else {
            Image(systemName: "circle").font(.system(size: 18)).foregroundStyle(TFTheme.textTertiary)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appColorScheme") private var colorSchemeValue: String = "dark"
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String? = nil
    @State private var showEditName = false
    @State private var editingName = ""

    private var isDarkMode: Bool {
        get { colorSchemeValue == "dark" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileCard
                        accountSection
                        appearanceSection
                        appSection
                        signOutButton
                        deleteAccountButton
                        versionFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(TFTheme.accentOrange)
                }
            }
        }
        .preferredColorScheme(colorSchemeValue == "light" ? .light : .dark)
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your training data.")
        }
        .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                isDeletingAccount = true
                Task {
                    do {
                        try await auth.deleteAccount()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all your training data, health records, and chat history. This cannot be undone.")
        }
        .alert("Delete Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(TFTheme.accentOrange.opacity(0.2))
                    .frame(width: 60, height: 60)
                Text(initials)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(auth.displayName.isEmpty ? "Athlete" : auth.displayName)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                if !auth.email.isEmpty {
                    Text(auth.email)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                } else {
                    Text("TrainFlow Member")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var initials: String {
        let parts = auth.displayName.split(separator: " ")
        if parts.isEmpty { return "A" }
        if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
        return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
    }

    private var accountSection: some View {
        settingsSection(title: "Account") {
            Button(action: {
                editingName = auth.displayName
                showEditName = true
            }) {
                settingsRowChevron(icon: "person.fill", color: TFTheme.accentBlue,
                                   label: "Display Name",
                                   value: auth.displayName.isEmpty ? "—" : auth.displayName)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showEditName) {
                EditNameSheet(editingName: $editingName, isPresented: $showEditName)
                    .environmentObject(auth)
            }
        }
    }

    private var appearanceSection: some View {
        settingsSection(title: "Appearance") {
            HStack(spacing: 12) {
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isDarkMode ? TFTheme.accentPurple : TFTheme.accentYellow)
                    .frame(width: 30, height: 30)
                    .background((isDarkMode ? TFTheme.accentPurple : TFTheme.accentYellow).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Dark Mode")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { colorSchemeValue == "dark" },
                    set: { colorSchemeValue = $0 ? "dark" : "light" }
                ))
                .tint(TFTheme.accentOrange)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var appSection: some View {
        settingsSection(title: "App") {
            settingsRow(icon: "heart.fill", color: TFTheme.accentRed, label: "Health Data", value: "HealthKit")
        }
    }

    private var signOutButton: some View {
        Button(action: { showSignOutConfirm = true }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TFTheme.accentRed)
                    .frame(width: 32, height: 32)
                    .background(TFTheme.accentRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Sign Out")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(TFTheme.accentRed)
                Spacer()
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var deleteAccountButton: some View {
        Button(action: { showDeleteConfirm = true }) {
            HStack {
                if isDeletingAccount {
                    ProgressView().tint(TFTheme.accentRed).frame(width: 32, height: 32)
                } else {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TFTheme.accentRed)
                        .frame(width: 32, height: 32)
                        .background(TFTheme.accentRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Text("Delete Account")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(TFTheme.accentRed)
                Spacer()
            }
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
        .disabled(isDeletingAccount)
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 28)).foregroundStyle(TFTheme.accentOrange.opacity(0.5))
            Text("TrainFlow")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(TFTheme.textTertiary.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(TFTheme.textTertiary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .glassCard(cornerRadius: 16)
        }
    }

    private func settingsRowChevron(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TFTheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(TFTheme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(TFTheme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Edit Name Sheet

private struct ProfileWrap: Decodable {
    let profile: [String: String]?
}

struct EditNameSheet: View {
    @Binding var editingName: String
    @Binding var isPresented: Bool
    @EnvironmentObject private var auth: AuthService
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                TFTheme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display Name")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TFTheme.textTertiary)
                            .padding(.horizontal, 4)
                        TextField("Your name", text: $editingName)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(TFTheme.textPrimary)
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView().tint(TFTheme.accentOrange)
                    } else {
                        Button("Save") { save() }
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(TFTheme.accentOrange)
                            .disabled(editingName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        Task {
            let _: ProfileWrap? = try? await APIClient.shared.put("/profile", body: ["name": trimmed])
            let _ = try? await Amplify.Auth.update(userAttribute: AuthUserAttribute(.name, value: trimmed))
            auth.displayName = trimmed
            isSaving = false
            isPresented = false
        }
    }
}
