import Foundation
import GoogleSignIn
import UIKit

/// Wraps Google Sign-In SDK and publishes the current auth state.
@MainActor
final class GoogleSignInService: ObservableObject {
    static let shared = GoogleSignInService()

    @Published var isSignedIn: Bool = false
    @Published var userDisplayName: String?
    @Published var userEmail: String?
    @Published var userPhotoURL: URL?
    @Published var errorMessage: String?

    private init() {
        // Restore previous session silently
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            Task { @MainActor [weak self] in
                if let user {
                    self?.applyUser(user)
                }
            }
        }
    }

    // MARK: - Public API

    /// Initiates the Google Sign-In flow from the given presenting view controller.
    func signIn(presenting viewController: UIViewController) {
        errorMessage = nil
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let error {
                    let nsError = error as NSError
                    // Ignore cancellation
                    if nsError.domain == GIDSignInErrorDomain,
                       nsError.code == GIDSignInError.canceled.rawValue { return }
                    self?.errorMessage = error.localizedDescription
                    return
                }
                if let user = result?.user {
                    self?.applyUser(user)
                }
            }
        }
    }

    /// Signs the current user out.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userDisplayName = nil
        userEmail = nil
        userPhotoURL = nil
    }

    /// Forward a URL received by the app to the SDK (required for the OAuth redirect).
    @discardableResult
    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Private

    private func applyUser(_ user: GIDGoogleUser) {
        isSignedIn = true
        userDisplayName = user.profile?.name
        userEmail = user.profile?.email
        userPhotoURL = user.profile?.imageURL(withDimension: 80)
    }
}
