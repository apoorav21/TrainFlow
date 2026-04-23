import SwiftUI

// MARK: - Login Mode

private enum LoginMode {
    case signIn, signUp, forgotPassword, passwordless
}

// MARK: - LoginView

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService

    @State private var mode: LoginMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    // Sign-up OTP confirmation state
    @State private var showOTPScreen = false
    @State private var pendingEmail = ""
    @State private var pendingPassword = ""

    // Forgot password state — step 1: email, step 2: code, step 3: new password
    @State private var fpStep = 1
    @State private var fpCode = ""
    @State private var fpNewPassword = ""

    // Passwordless state
    @State private var plCodeSent = false
    @State private var plCode = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D0D0F"), TFTheme.accentOrange.opacity(0.15), Color(hex: "0D0D0F")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            if showOTPScreen {
                OTPConfirmView(
                    email: pendingEmail,
                    password: pendingPassword,
                    onBack: {
                        withAnimation(.spring(response: 0.3)) {
                            showOTPScreen = false
                            errorMessage = nil
                        }
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        formCard
                        bottomLinks
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: showOTPScreen)
        .animation(.spring(response: 0.35), value: mode)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            ZStack {
                Circle().fill(TFTheme.accentOrange.opacity(0.2)).frame(width: 90, height: 90)
                Image(systemName: heroIcon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(TFTheme.accentOrange)
            }
            VStack(spacing: 8) {
                Text("TrainFlow")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                Text(heroSubtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer().frame(height: 36)
        }
    }

    private var heroIcon: String {
        switch mode {
        case .signIn: return "figure.run.circle.fill"
        case .signUp: return "person.badge.plus.fill"
        case .forgotPassword: return "key.fill"
        case .passwordless: return "envelope.badge.shield.half.filled.fill"
        }
    }

    private var heroSubtitle: String {
        switch mode {
        case .signIn: return "Welcome back, athlete"
        case .signUp: return "Create your account to get started"
        case .forgotPassword:
            if fpStep == 1 { return "We'll email you a reset code" }
            if fpStep == 2 { return "Enter the code sent to your email" }
            return "Choose your new password"
        case .passwordless: return plCodeSent ? "Enter the code we sent to your email" : "Sign in with a one-time code"
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 14) {
            switch mode {
            case .signIn:    signInFields
            case .signUp:    signUpFields
            case .forgotPassword: forgotPasswordFields
            case .passwordless:  passwordlessFields
            }

            errorBanner
            successBanner
            primaryButton
        }
        .padding(24)
        .background(TFTheme.bgCard.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Sign In Fields

    @ViewBuilder
    private var signInFields: some View {
        AuthField(icon: "envelope.fill", placeholder: "Email address", text: $email, isEmail: true)
        VStack(alignment: .trailing, spacing: 6) {
            AuthField(icon: "lock.fill", placeholder: "Password", text: $password, isPassword: true)
            Button(action: { switchMode(.forgotPassword) }) {
                Text("Forgot password?")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(TFTheme.accentOrange)
            }
        }
    }

    // MARK: - Sign Up Fields

    @ViewBuilder
    private var signUpFields: some View {
        AuthField(icon: "person.fill", placeholder: "Your name", text: $displayName)
        AuthField(icon: "envelope.fill", placeholder: "Email address", text: $email, isEmail: true)
        AuthField(icon: "lock.fill", placeholder: "Password", text: $password, isPassword: true)
        passwordRequirementsView
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Forgot Password Fields (3-step)

    @ViewBuilder
    private var forgotPasswordFields: some View {
        switch fpStep {
        case 1:
            AuthField(icon: "envelope.fill", placeholder: "Email address", text: $email, isEmail: true)
        case 2:
            VStack(alignment: .leading, spacing: 4) {
                AuthField(icon: "number.circle.fill", placeholder: "6-digit code", text: $fpCode, isNumeric: true)
                Text("Sent to \(email)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(TFTheme.textTertiary)
                    .padding(.leading, 4)
            }
        default:
            AuthField(icon: "lock.fill", placeholder: "New password", text: $fpNewPassword, isPassword: true)
            requirementsView(for: fpNewPassword)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Passwordless Fields

    @ViewBuilder
    private var passwordlessFields: some View {
        if !plCodeSent {
            AuthField(icon: "envelope.fill", placeholder: "Email address", text: $email, isEmail: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                AuthField(icon: "number.circle.fill", placeholder: "6-digit code", text: $plCode, isNumeric: true)
                Text("Sent to \(email)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(TFTheme.textTertiary)
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - Error / Success Banners

    @ViewBuilder
    private var errorBanner: some View {
        if let err = errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TFTheme.accentRed)
                Text(err)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(TFTheme.accentRed.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    private var successBanner: some View {
        if let msg = successMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TFTheme.accentGreen)
                Text(msg)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(TFTheme.accentGreen.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button(action: submit) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TFTheme.accentOrange)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonLabel)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 54)
        }
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.2), value: isFormValid)
    }

    private var buttonLabel: String {
        switch mode {
        case .signIn:        return "Sign In"
        case .signUp:        return "Create Account"
        case .forgotPassword:
            if fpStep == 1 { return "Send Reset Code" }
            if fpStep == 2 { return "Verify Code" }
            return "Reset Password"
        case .passwordless:  return plCodeSent ? "Verify & Sign In" : "Send Code"
        }
    }

    // MARK: - Bottom Links

    @ViewBuilder
    private var bottomLinks: some View {
        VStack(spacing: 12) {
            switch mode {
            case .signIn:
                Button(action: { switchMode(.passwordless) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.open.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Sign in without a password")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(TFTheme.accentOrange)
                }
                accountToggle

            case .signUp:
                accountToggle

            case .forgotPassword, .passwordless:
                Button(action: { switchMode(.signIn) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back to Sign In")
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(TFTheme.textSecondary)
                }

                if mode == .forgotPassword && fpStep >= 2 {
                    Button(action: resendForgotCode) {
                        Text("Resend code")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(TFTheme.accentOrange)
                    }
                }
                if mode == .passwordless && plCodeSent {
                    Button(action: resendSignInCode) {
                        Text("Resend code")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(TFTheme.accentOrange)
                    }
                }
            }
        }
        .padding(.top, 20)
    }

    private var accountToggle: some View {
        Button(action: { switchMode(mode == .signUp ? .signIn : .signUp) }) {
            HStack(spacing: 6) {
                Text(mode == .signUp ? "Already have an account?" : "Don't have an account?")
                    .foregroundStyle(TFTheme.textSecondary)
                Text(mode == .signUp ? "Sign in" : "Sign up")
                    .foregroundStyle(TFTheme.accentOrange).fontWeight(.bold)
            }
            .font(.system(.subheadline, design: .rounded))
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        let hasEmail = email.contains("@") && email.contains(".")
        switch mode {
        case .signIn:
            return hasEmail && password.count >= 6
        case .signUp:
            let allMet = passwordRequirements.allSatisfy { $0.1 }
            return hasEmail && allMet && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        case .forgotPassword:
            if fpStep == 1 { return hasEmail }
            if fpStep == 2 { return fpCode.count == 6 }
            return requirements(for: fpNewPassword).allSatisfy { $0.1 }
        case .passwordless:
            if plCodeSent { return plCode.count == 6 }
            return hasEmail
        }
    }

    // MARK: - Password Requirements

    private func requirements(for pwd: String) -> [(String, Bool)] {
        [
            ("At least 8 characters", pwd.count >= 8),
            ("One uppercase letter", pwd.contains(where: { $0.isUppercase })),
            ("One lowercase letter", pwd.contains(where: { $0.isLowercase })),
            ("One number", pwd.contains(where: { $0.isNumber })),
        ]
    }

    // Shorthand for the sign-up flow which uses the main `password` field
    private var passwordRequirements: [(String, Bool)] { requirements(for: password) }

    private func requirementsView(for pwd: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(requirements(for: pwd), id: \.0) { label, met in
                HStack(spacing: 8) {
                    Image(systemName: met ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(met ? TFTheme.accentGreen : TFTheme.textTertiary)
                        .animation(.easeInOut(duration: 0.2), value: met)
                    Text(label)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(met ? TFTheme.accentGreen : TFTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private var passwordRequirementsView: some View { requirementsView(for: password) }

    // MARK: - Actions

    private func switchMode(_ newMode: LoginMode) {
        withAnimation(.spring(response: 0.3)) {
            mode = newMode
            errorMessage = nil
            successMessage = nil
            fpStep = 1
            fpCode = ""
            fpNewPassword = ""
            plCodeSent = false
            plCode = ""
        }
    }

    private func submit() {
        Task { await performSubmit() }
    }

    @MainActor
    private func performSubmit() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)

        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: trimmedEmail, password: password)

            case .signUp:
                let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
                try await auth.signUp(email: trimmedEmail, password: password, displayName: trimmedName)

            case .forgotPassword:
                if fpStep == 1 {
                    try await auth.sendPasswordReset(email: trimmedEmail)
                    withAnimation { fpStep = 2 }
                    successMessage = "A reset code was sent to \(trimmedEmail)."
                } else if fpStep == 2 {
                    // Just store the code and advance — confirmResetPassword needs both at once
                    withAnimation { fpStep = 3; successMessage = nil; errorMessage = nil }
                } else {
                    try await auth.confirmPasswordReset(email: trimmedEmail, code: fpCode, newPassword: fpNewPassword)
                }

            case .passwordless:
                if !plCodeSent {
                    try await auth.sendSignInCode(email: trimmedEmail)
                    if !auth.isSignedIn {
                        withAnimation { plCodeSent = true }
                        successMessage = "A sign-in code was sent to \(trimmedEmail)."
                    }
                } else {
                    try await auth.confirmSignInWithCode(plCode)
                }
            }
        } catch AuthError.emailConfirmationRequired {
            pendingEmail = trimmedEmail
            pendingPassword = password
            withAnimation(.spring(response: 0.4)) { showOTPScreen = true }
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }

        isLoading = false
    }

    private func resendForgotCode() {
        Task {
            let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
            do {
                try await auth.sendPasswordReset(email: trimmedEmail)
                withAnimation {
                    fpStep = 2
                    fpCode = ""
                    successMessage = "A new code was sent."
                    errorMessage = nil
                }
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
        }
    }

    private func resendSignInCode() {
        Task {
            let trimmedEmail = email.lowercased().trimmingCharacters(in: .whitespaces)
            do {
                try await auth.sendSignInCode(email: trimmedEmail)
                withAnimation { successMessage = "A new code was sent." }
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - OTP Confirmation Screen (sign-up email verification)

struct OTPConfirmView: View {
    @EnvironmentObject private var auth: AuthService
    let email: String
    let password: String
    var onBack: () -> Void

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resendSent = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                ZStack {
                    Circle().fill(TFTheme.accentOrange.opacity(0.2)).frame(width: 90, height: 90)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(TFTheme.accentOrange)
                }
                .padding(.bottom, 24)

                VStack(spacing: 8) {
                    Text("Check your email")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(TFTheme.textPrimary)
                    Text("Enter the 6-digit code sent to\n\(email)")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(TFTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 36)

                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(TFTheme.accentOrange)
                            .frame(width: 24)
                        TextField("6-digit code", text: $code)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(TFTheme.textPrimary)
                            .keyboardType(.numberPad)
                            .tracking(8)
                            .onChange(of: code) { _, newValue in
                                code = String(newValue.filter(\.isNumber).prefix(6))
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(TFTheme.bgPrimary.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let err = errorMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(TFTheme.accentRed)
                            Text(err)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(TFTheme.textPrimary)
                            Spacer()
                        }
                        .padding(12)
                        .background(TFTheme.accentRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if resendSent {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(TFTheme.accentGreen)
                            Text("New code sent!").font(.system(.caption, design: .rounded)).foregroundStyle(TFTheme.accentGreen)
                        }
                    }

                    Button(action: verify) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(TFTheme.accentOrange)
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Verify & Sign In")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 54)
                    }
                    .disabled(isLoading || code.count < 6)
                    .opacity(code.count == 6 ? 1 : 0.5)
                }
                .padding(24)
                .background(TFTheme.bgCard.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 12) {
                    Button(action: resend) {
                        HStack(spacing: 6) {
                            Text("Didn't get a code?").foregroundStyle(TFTheme.textSecondary)
                            Text("Resend").foregroundStyle(TFTheme.accentOrange).fontWeight(.bold)
                        }
                        .font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(isLoading)

                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(TFTheme.textTertiary)
                    }
                }
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
        }
    }

    private func verify() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await auth.confirmSignUp(email: email, code: code, password: password)
            } catch {
                withAnimation { errorMessage = error.localizedDescription }
            }
            isLoading = false
        }
    }

    private func resend() {
        resendSent = false
        Task {
            do {
                try await auth.resendConfirmationCode(email: email)
                resendSent = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Auth Field

struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isEmail = false
    var isPassword = false
    var isNumeric = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TFTheme.accentOrange)
                .frame(width: 24)
            if isPassword {
                SecureField(placeholder, text: $text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(TFTheme.textPrimary)
                    .keyboardType(isEmail ? .emailAddress : isNumeric ? .numberPad : .default)
                    .textInputAutocapitalization(isEmail || isNumeric ? .never : .words)
                    .autocorrectionDisabled(isEmail || isNumeric)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(TFTheme.bgPrimary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
