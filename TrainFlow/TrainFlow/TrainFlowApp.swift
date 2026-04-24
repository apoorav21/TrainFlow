import SwiftUI

@main
struct TrainFlowApp: App {
    @StateObject private var auth = AuthService.shared
    @AppStorage("appColorScheme") private var colorSchemeValue: String = "dark"

    private var preferredScheme: ColorScheme? {
        colorSchemeValue == "light" ? .light : .dark
    }

    init() {
        AuthService.shared.configureAmplify()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isCheckingSession {
                    SplashView()
                } else if auth.isSignedIn {
                    MainTabView()
                        .environmentObject(auth)
                } else {
                    LoginView()
                        .environmentObject(auth)
                }
            }
            .preferredColorScheme(preferredScheme)
            .animation(.easeInOut(duration: 0.4), value: auth.isCheckingSession)
            .animation(.easeInOut(duration: 0.4), value: auth.isSignedIn)
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            ) { _ in
                HealthSyncService.shared.syncIfNeeded()
                if AuthService.shared.isSignedIn {
                    Task { await PhoneSessionManager.shared.pushTodayWorkoutToWatch() }
                }
            }
            .task {
                if auth.isSignedIn {
                    HealthSyncService.shared.syncIfNeeded()
                    await LocationService.shared.requestLocationAndUpdate()
                    await PhoneSessionManager.shared.pushTodayWorkoutToWatch()
                }
            }
        }
    }
}
