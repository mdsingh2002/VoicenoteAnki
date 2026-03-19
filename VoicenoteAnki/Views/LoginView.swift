import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @ObservedObject private var signInService = GoogleSignInService.shared
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                Spacer()

                logoSection

                Spacer().frame(height: 64)

                signInCard
                    .padding(.horizontal, 24)

                Spacer()

                footerNote
                    .padding(.bottom, 36)
            }
        }
    }

    // MARK: - Subviews

    private var logoSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .frame(width: 100, height: 100)
                    .glassEffect(.regular, in: Circle())

                Image(systemName: "mic.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("VoiceNote Anki")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Record. Transcribe. Learn.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var signInCard: some View {
        VStack(spacing: 20) {
            Text("Sign in to continue")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))

            googleButton

            if let error = signInService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .padding(24)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var googleButton: some View {
        Button(action: handleSignIn) {
            HStack(spacing: 12) {
                if isSigningIn {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    // Google "G" icon rendered from SF Symbols globe as a stand-in
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                        Text("G")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                    }
                }

                Text(isSigningIn ? "Signing in…" : "Continue with Google")
                    .font(.body.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSigningIn)
        .animation(.easeInOut(duration: 0.2), value: isSigningIn)
    }

    private var footerNote: some View {
        Text("Your voice notes stay on device.\nSign-in keeps your account in sync.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.35))
            .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func handleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }

        isSigningIn = true
        signInService.errorMessage = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak signInService] result, error in
            Task { @MainActor in
                isSigningIn = false
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == GIDSignInErrorDomain,
                       nsError.code == GIDSignInError.canceled.rawValue { return }
                    signInService?.errorMessage = error.localizedDescription
                    return
                }
                if let user = result?.user {
                    signInService?.isSignedIn = true
                    signInService?.userDisplayName = user.profile?.name
                    signInService?.userEmail = user.profile?.email
                    signInService?.userPhotoURL = user.profile?.imageURL(withDimension: 80)
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.06, blue: 0.18),
                Color(red: 0.08, green: 0.04, blue: 0.22),
                Color(red: 0.02, green: 0.08, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
