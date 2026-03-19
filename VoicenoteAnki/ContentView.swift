import SwiftUI

struct ContentView: View {
    @StateObject private var recordingVM = RecordingViewModel()
    @ObservedObject private var signInService = GoogleSignInService.shared
    @State private var selectedTab = 0
    @State private var showAPIKeySetup = false

    private var flashcardsVM: FlashcardsViewModel { recordingVM.flashcardsVM }

    var body: some View {
        Group {
            if signInService.isSignedIn {
                mainTabs
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: signInService.isSignedIn)
    }

    // MARK: - Main app (post-login)

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            RecordingView(vm: recordingVM)
                .tabItem { Label("Record", systemImage: "mic.fill") }
                .tag(0)

            FlashcardsView(vm: flashcardsVM, onTapAPIKey: { showAPIKeySetup = true })
                .tabItem { Label("Flashcards", systemImage: "rectangle.stack.fill") }
                .tag(1)
                .badge(flashcardsVM.isGenerating ? 1 : 0)
        }
        .tint(.white)
        // Preview sheet: shown as soon as generation finishes
        .sheet(item: Binding(
            get: { flashcardsVM.pendingDeck },
            set: { if $0 == nil { flashcardsVM.discardPendingDeck() } }
        )) { deck in
            GenerationPreviewView(vm: flashcardsVM, deck: deck)
        }
        // API key setup sheet
        .sheet(isPresented: $showAPIKeySetup) {
            APIKeySetupView()
        }
        // Navigate to Flashcards tab when a deck is confirmed
        .onReceive(flashcardsVM.$decks) { decks in
            if decks.count == 1 && selectedTab == 0 {
                withAnimation { selectedTab = 1 }
            }
        }
    }
}
