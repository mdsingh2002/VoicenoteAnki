import SwiftUI
import GoogleSignIn

@main
struct VoicenoteAnkiApp: App {
    init() {
        // Seed the generation service with the persisted API key on every launch.
        FlashcardGenerationService.apiKey = APIKeyService.shared.apiKey ?? ""
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Forward OAuth redirect URLs to the Google Sign-In SDK.
                .onOpenURL { url in
                    GoogleSignInService.shared.handle(url)
                }
        }
    }
}
