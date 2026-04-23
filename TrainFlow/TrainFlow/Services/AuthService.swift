import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore

// MARK: - Auth Service
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()
    private init() { }

    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var isCheckingSession: Bool = true
    @Published var needsEmailConfirmation: Bool = false
    @Published var displayName: String = ""
    @Published var email: String = ""

    var userId: String?

    /// Returns the Cognito ID token for the current session, or nil if not signed in.
    /// Amplify automatically refreshes the token when needed.
    var accessToken: String? {
        // Synchronous access is not available via Amplify; callers should use validAccessToken().
        // This property exists for backward-compatibility surface only.
        nil
    }

    // MARK: - Amplify Configuration

    /// Call once at app launch, before any auth operations.
    /// Reads configuration from amplifyconfiguration.json in the app bundle.
    /// Fill in the placeholder values in that file after CDK deployment.
    func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
            NSLog("[AuthService] Amplify configured successfully")
        } catch {
            NSLog("[AuthService] Amplify configure error: \(error)")
        }

        // Check existing session on launch
        Task { await checkCurrentSession() }

        // Observe Hub auth events for sign-in / sign-out changes
        Task { await observeAuthEvents() }
    }

    // MARK: - Session Check

    private func checkCurrentSession() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            isSignedIn = session.isSignedIn
            if session.isSignedIn {
                userId = await fetchUserId()
                await fetchDisplayName()
            }
            NSLog("[AuthService] Session check: isSignedIn=\(isSignedIn)")
        } catch {
            NSLog("[AuthService] Could not fetch auth session: \(error)")
            isSignedIn = false
        }
        isCheckingSession = false
    }

    private func fetchUserId() async -> String? {
        do {
            let user = try await Amplify.Auth.getCurrentUser()
            return user.userId
        } catch {
            return nil
        }
    }

    func fetchDisplayName() async {
        do {
            let attributes = try await Amplify.Auth.fetchUserAttributes()
            if let nameAttr = attributes.first(where: { $0.key == .name }) {
                displayName = nameAttr.value
            }
            if let emailAttr = attributes.first(where: { $0.key == .email }) {
                email = emailAttr.value
            }
        } catch {
            NSLog("[AuthService] Could not fetch user attributes: \(error)")
        }
    }

    // MARK: - Hub Observation

    private func observeAuthEvents() async {
        let stream = Amplify.Hub.publisher(for: .auth)
        for await payload in stream.values {
            switch payload.eventName {
            case HubPayload.EventName.Auth.signedIn:
                isSignedIn = true
                userId = await fetchUserId()
                NSLog("[AuthService] Hub: user signed in")
            case HubPayload.EventName.Auth.signedOut,
                 HubPayload.EventName.Auth.sessionExpired,
                 HubPayload.EventName.Auth.userDeleted:
                isSignedIn = false
                userId = nil
                NSLog("[AuthService] Hub: user signed out / session expired")
            default:
                break
            }
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, displayName: String) async throws {
        let userAttributes = [AuthUserAttribute(.email, value: email),
                              AuthUserAttribute(.name, value: displayName)]
        let options = AuthSignUpRequest.Options(userAttributes: userAttributes)

        do {
            let result = try await Amplify.Auth.signUp(username: email, password: password, options: options)
            NSLog("[AuthService] SignUp result: \(result.nextStep)")

            switch result.nextStep {
            case .confirmUser:
                needsEmailConfirmation = true
                throw AuthError.emailConfirmationRequired
            case .done:
                // Email confirmation is disabled in Cognito — auto sign in
                try await signIn(email: email, password: password)
            default:
                break
            }
        } catch let ours as AuthError {
            throw ours  // Re-throw our own errors (e.g. emailConfirmationRequired) unchanged
        } catch {
            throw mapError(error)  // Map Amplify/network errors to friendly messages
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Amplify.Auth.signIn(username: email, password: password)
            NSLog("[AuthService] SignIn result: \(result.nextStep)")

            if result.isSignedIn {
                isSignedIn = true
                needsEmailConfirmation = false
                userId = await fetchUserId()
                await fetchDisplayName()
            }
            // Other next steps (MFA, etc.) not yet handled — future enhancement
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Confirm Sign Up (OTP)

    /// Confirms sign-up using the OTP code sent to the user's email.
    /// Automatically signs the user in on success.
    func confirmSignUp(email: String, code: String, password: String) async throws {
        do {
            let result = try await Amplify.Auth.confirmSignUp(for: email, confirmationCode: code)
            NSLog("[AuthService] ConfirmSignUp result: \(result.nextStep)")
            // Auto sign-in after confirmation
            try await signIn(email: email, password: password)
        } catch let ours as AuthError {
            throw ours
        } catch {
            throw mapError(error)
        }
    }

    /// Resends the confirmation OTP to the user's email.
    func resendConfirmationCode(email: String) async throws {
        do {
            _ = try await Amplify.Auth.resendSignUpCode(for: email)
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Sign Out

    func signOut() {
        Task {
            _ = await Amplify.Auth.signOut()
            await MainActor.run {
                isSignedIn = false
                needsEmailConfirmation = false
                userId = nil
                displayName = ""
                email = ""
            }
            NSLog("[AuthService] Signed out")
        }
    }

    // MARK: - Delete Account

    /// Deletes all user data from the backend, then removes the Cognito user.
    func deleteAccount() async throws {
        // 1. Wipe all backend data for this user
        do {
            try await APIClient.shared.delete("/account")
        } catch {
            NSLog("[AuthService] Backend delete failed: \(error.localizedDescription)")
            throw error
        }

        // 2. Delete the Cognito user (requires a valid session)
        do {
            try await Amplify.Auth.deleteUser()
        } catch {
            NSLog("[AuthService] Cognito deleteUser failed: \(error.localizedDescription)")
            throw error
        }

        await MainActor.run {
            isSignedIn = false
            needsEmailConfirmation = false
            userId = nil
            displayName = ""
            email = ""
        }
    }

    // MARK: - Valid Access Token

    /// Returns the current Cognito ID token, refreshing it automatically if expired.
    /// Returns nil if the user is not signed in.
    func validAccessToken() async -> String? {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            guard session.isSignedIn else { return nil }

            // Cast to the Cognito-specific session to extract tokens
            guard let cognitoSession = session as? AuthCognitoTokensProvider else {
                NSLog("[AuthService] Session does not provide Cognito tokens")
                return nil
            }
            let tokens = try cognitoSession.getCognitoTokens().get()
            return tokens.idToken
        } catch {
            NSLog("[AuthService] Failed to get valid token: \(error)")
            return nil
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async throws {
        do {
            _ = try await Amplify.Auth.resetPassword(for: email)
        } catch {
            throw mapError(error)
        }
    }

    func confirmPasswordReset(email: String, code: String, newPassword: String) async throws {
        do {
            try await Amplify.Auth.confirmResetPassword(for: email, with: newPassword, confirmationCode: code)
            // Auto sign-in after successful reset
            try await signIn(email: email, password: newPassword)
        } catch let ours as AuthError {
            throw ours
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Passwordless (custom auth / email-OTP)

    /// Initiates a passwordless email-OTP sign-in via Cognito custom auth flow.
    /// Requires the user pool to have DefineAuthChallenge / CreateAuthChallenge /
    /// VerifyAuthChallenge Lambda triggers configured.
    func sendSignInCode(email: String) async throws {
        do {
            let options = AuthSignInRequest.Options(
                pluginOptions: AWSAuthSignInOptions(authFlowType: .customWithoutSRP)
            )
            let result = try await Amplify.Auth.signIn(username: email, password: "", options: options)
            if result.isSignedIn {
                isSignedIn = true
                userId = await fetchUserId()
                await fetchDisplayName()
                return
            }
            guard case .confirmSignInWithCustomChallenge = result.nextStep else {
                throw TrainFlowAuthError.serverError("Unexpected sign-in step. Please try with a password instead.")
            }
        } catch let ours as AuthError {
            throw ours
        } catch {
            throw mapError(error)
        }
    }

    func confirmSignInWithCode(_ code: String) async throws {
        do {
            let result = try await Amplify.Auth.confirmSignIn(challengeResponse: code)
            if result.isSignedIn {
                isSignedIn = true
                userId = await fetchUserId()
                await fetchDisplayName()
            }
        } catch {
            throw mapError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: Error) -> Error {
        // Cast to AmplifyError protocol to get the real description string.
        // Amplify.AuthError is a module-level type that can't be directly qualified
        // due to naming conflict with the local AuthError enum — use the protocol instead.
        if let ae = error as? AmplifyError {
            return TrainFlowAuthError.serverError(friendlyMessage(ae.errorDescription))
        }
        return TrainFlowAuthError.serverError(friendlyMessage(error.localizedDescription))
    }

    private func friendlyMessage(_ raw: String) -> String {
        let s = raw.lowercased()
        if s.contains("incorrect username or password") || s.contains("notauthorizedexception") {
            return "Wrong email or password. Please try again."
        } else if s.contains("user is not confirmed") || s.contains("usernotconfirmedexception") {
            return "Please verify your email before signing in."
        } else if s.contains("user already exists") || s.contains("usernameexistsexception") {
            return "An account with this email already exists. Try signing in."
        } else if s.contains("password did not conform") || s.contains("invalidpasswordexception") {
            return "Password must be at least 8 characters with uppercase, lowercase, and a number."
        } else if s.contains("limitexceededexception") || s.contains("too many") {
            return "Too many attempts. Please wait a few minutes and try again."
        } else if s.contains("codemismatchexception") || s.contains("invalid verification code") {
            return "Incorrect code. Please check and try again."
        } else if s.contains("expiredcodeexception") {
            return "This code has expired. Please request a new one."
        } else if s.contains("usernotfoundexception") || s.contains("user does not exist") {
            return "No account found with this email."
        } else if s.contains("custom_auth is not enabled") || s.contains("customauth") || s.contains("invalidparameter") && s.contains("custom") {
            return "Passwordless sign-in isn't available yet — it requires a backend update. Please sign in with your password for now."
        } else if s.contains("network") || s.contains("internet") || s.contains("connection") {
            return "Connection issue. Please check your internet and try again."
        }
        return "Something went wrong. Please try again."
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidURL, invalidResponse, httpError(Int), serverError(String), emailConfirmationRequired

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .httpError(let c): return "Server error \(c)"
        case .serverError(let m): return m
        case .emailConfirmationRequired:
            return "Please check your email to confirm your account, then sign in."
        }
    }
}

/// Internal error type used when mapping Amplify errors back to surface-level errors.
/// Named distinctly to avoid clash with `Amplify.AuthError`.
private enum TrainFlowAuthError: LocalizedError {
    case serverError(String)
    var errorDescription: String? {
        if case .serverError(let m) = self { return m }
        return nil
    }
}
