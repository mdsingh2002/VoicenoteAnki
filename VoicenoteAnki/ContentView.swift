import SwiftUI

struct ContentView: View {
    @StateObject private var recordingVM = RecordingViewModel()
    @State private var selectedTab = 0
    @State private var showAPIKeySetup = false

    private var flashcardsVM: FlashcardsViewModel { recordingVM.flashcardsVM }

    var body: some View {
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
