import SwiftUI

struct ContentView: View {
    /// Single source of truth shared between tabs.
    @StateObject private var recordingVM = RecordingViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingView(vm: recordingVM)
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(0)

            FlashcardsView(vm: recordingVM.flashcardsVM)
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.stack.fill")
                }
                .tag(1)
                .badge(newDeckBadge)
        }
        .tint(.white)
        .onReceive(recordingVM.flashcardsVM.$decks) { decks in
            // Auto-navigate to Flashcards tab when first deck arrives
            if decks.count == 1 && selectedTab == 0 {
                withAnimation { selectedTab = 1 }
            }
        }
    }

    /// Show a badge dot on the Flashcards tab while generation is in progress.
    private var newDeckBadge: Int {
        recordingVM.flashcardsVM.isGenerating ? 1 : 0
    }
}
