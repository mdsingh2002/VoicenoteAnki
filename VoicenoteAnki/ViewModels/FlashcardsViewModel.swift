import SwiftUI
import Combine

@MainActor
final class FlashcardsViewModel: ObservableObject {

    // MARK: - Published state
    @Published private(set) var decks: [FlashcardDeck] = []
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    /// Deck waiting for user review before being committed to `decks`.
    @Published private(set) var pendingDeck: FlashcardDeck?

    // Active study session
    @Published var activeDeck: FlashcardDeck?
    @Published private(set) var currentCardIndex: Int = 0
    @Published private(set) var isShowingBack = false
    @Published private(set) var sessionComplete = false

    // MARK: - Private
    private let service = FlashcardGenerationService()

    // MARK: - Generation

    func generateDeck(for note: VoiceNote) async {
        guard !note.transcript.isEmpty else {
            errorMessage = "No transcript yet — finish recording first."
            return
        }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let cards = try await service.generateFlashcards(from: note.transcript, noteID: note.id)
            let deck  = FlashcardDeck(sourceNote: note, cards: cards)
            // Surface for preview; committed via confirmPendingDeck()
            pendingDeck = deck
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Pending deck management

    /// User approved the preview — move the pending deck into the saved list.
    func confirmPendingDeck(_ deck: FlashcardDeck) {
        decks.insert(deck, at: 0)
        pendingDeck = nil
    }

    /// User discarded the preview.
    func discardPendingDeck() {
        pendingDeck = nil
    }

    /// Edit a card inside the pending deck.
    func updatePendingCard(_ card: Flashcard) {
        guard var deck = pendingDeck,
              let idx = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        deck.cards[idx] = card
        pendingDeck = deck
    }

    func deletePendingCard(at offsets: IndexSet) {
        guard var deck = pendingDeck else { return }
        deck.cards.remove(atOffsets: offsets)
        pendingDeck = deck
    }

    // MARK: - Study session

    func startStudySession(deck: FlashcardDeck) {
        activeDeck      = deck
        currentCardIndex = 0
        isShowingBack   = false
        sessionComplete = false
    }

    func endStudySession() {
        activeDeck = nil
        sessionComplete = false
    }

    func flipCard() {
        withAnimation(.spring(duration: 0.4)) {
            isShowingBack.toggle()
        }
    }

    func nextCard() {
        guard let deck = activeDeck else { return }
        isShowingBack = false
        if currentCardIndex < deck.cards.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentCardIndex += 1
            }
        } else {
            withAnimation(.spring(duration: 0.4)) {
                sessionComplete = true
            }
        }
    }

    func previousCard() {
        guard currentCardIndex > 0 else { return }
        isShowingBack = false
        withAnimation(.easeInOut(duration: 0.25)) {
            currentCardIndex -= 1
        }
    }

    func restartSession() {
        currentCardIndex = 0
        isShowingBack    = false
        sessionComplete  = false
    }

    // MARK: - Helpers

    var currentCard: Flashcard? {
        guard let deck = activeDeck, deck.cards.indices.contains(currentCardIndex) else { return nil }
        return deck.cards[currentCardIndex]
    }

    var progressFraction: Double {
        guard let deck = activeDeck, !deck.cards.isEmpty else { return 0 }
        return Double(currentCardIndex + 1) / Double(deck.cards.count)
    }

    func deleteDeck(at offsets: IndexSet) {
        decks.remove(atOffsets: offsets)
    }
}
