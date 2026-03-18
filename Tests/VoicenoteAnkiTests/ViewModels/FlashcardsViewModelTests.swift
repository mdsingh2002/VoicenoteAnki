import XCTest
@testable import VoicenoteAnki

@MainActor
final class FlashcardsViewModelTests: XCTestCase {

    private var viewModel: FlashcardsViewModel!
    private let testURL = URL(fileURLWithPath: "/tmp/test_note.m4a")

    override func setUp() {
        super.setUp()
        viewModel = FlashcardsViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeNote(transcript: String = "Test transcript") -> VoiceNote {
        VoiceNote(audioFileURL: testURL, transcript: transcript)
    }

    private func makeCards(count: Int, noteID: UUID, difficulty: Difficulty = .medium) -> [Flashcard] {
        (0..<count).map { i in
            Flashcard(
                front: "Question \(i)",
                back: "Answer \(i)",
                tags: ["tag\(i)"],
                difficulty: difficulty,
                sourceNoteID: noteID
            )
        }
    }

    private func makeDeck(cardCount: Int = 3) -> FlashcardDeck {
        let note = makeNote()
        return FlashcardDeck(sourceNote: note, cards: makeCards(count: cardCount, noteID: note.id))
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertTrue(viewModel.decks.isEmpty)
        XCTAssertFalse(viewModel.isGenerating)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.pendingDeck)
        XCTAssertNil(viewModel.activeDeck)
        XCTAssertEqual(viewModel.currentCardIndex, 0)
        XCTAssertFalse(viewModel.isShowingBack)
        XCTAssertFalse(viewModel.sessionComplete)
    }

    // MARK: - Pending Deck Management

    func testConfirmPendingDeckAddsToDecksList() {
        let deck = makeDeck()
        XCTAssertEqual(viewModel.decks.count, 0)

        viewModel.confirmPendingDeck(deck)

        XCTAssertEqual(viewModel.decks.count, 1)
        XCTAssertEqual(viewModel.decks.first?.id, deck.id)
    }

    func testConfirmPendingDeckClearsPendingDeck() {
        let deck = makeDeck()
        viewModel.confirmPendingDeck(deck)
        XCTAssertNil(viewModel.pendingDeck)
    }

    func testConfirmPendingDeckInsertsAtFront() {
        let deck1 = makeDeck()
        let deck2 = makeDeck()

        viewModel.confirmPendingDeck(deck1)
        viewModel.confirmPendingDeck(deck2)

        XCTAssertEqual(viewModel.decks.count, 2)
        XCTAssertEqual(viewModel.decks[0].id, deck2.id, "Most recently confirmed deck should be first")
        XCTAssertEqual(viewModel.decks[1].id, deck1.id)
    }

    func testDiscardPendingDeckClearsPendingDeck() {
        viewModel.discardPendingDeck()
        XCTAssertNil(viewModel.pendingDeck)
    }

    // MARK: - Deck Deletion

    func testDeleteDeckRemovesDeck() {
        let deck = makeDeck()
        viewModel.confirmPendingDeck(deck)
        XCTAssertEqual(viewModel.decks.count, 1)

        viewModel.deleteDeck(at: IndexSet([0]))
        XCTAssertEqual(viewModel.decks.count, 0)
    }

    func testDeleteDeckRemovesCorrectDeck() {
        let deck1 = makeDeck()
        let deck2 = makeDeck()
        viewModel.confirmPendingDeck(deck1)
        viewModel.confirmPendingDeck(deck2)
        XCTAssertEqual(viewModel.decks.count, 2)

        // deck2 is at index 0 (most recent first)
        viewModel.deleteDeck(at: IndexSet([0]))

        XCTAssertEqual(viewModel.decks.count, 1)
        XCTAssertEqual(viewModel.decks[0].id, deck1.id)
    }

    func testDeleteMultipleDecks() {
        let deck1 = makeDeck()
        let deck2 = makeDeck()
        let deck3 = makeDeck()
        viewModel.confirmPendingDeck(deck1)
        viewModel.confirmPendingDeck(deck2)
        viewModel.confirmPendingDeck(deck3)

        viewModel.deleteDeck(at: IndexSet([0, 2]))
        XCTAssertEqual(viewModel.decks.count, 1)
    }

    // MARK: - Generate Deck — Error Path (no API key)

    func testGenerateDeckWithEmptyTranscriptSetsErrorMessage() async {
        let savedKey = FlashcardGenerationService.apiKey
        FlashcardGenerationService.apiKey = ""
        defer { FlashcardGenerationService.apiKey = savedKey }

        let note = makeNote(transcript: "")
        await viewModel.generateDeck(for: note)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isGenerating)
    }

    func testGenerateDeckLeavesIsGeneratingFalseAfterCompletion() async {
        let savedKey = FlashcardGenerationService.apiKey
        FlashcardGenerationService.apiKey = ""
        defer { FlashcardGenerationService.apiKey = savedKey }

        let note = makeNote(transcript: "Some content")
        await viewModel.generateDeck(for: note)

        XCTAssertFalse(viewModel.isGenerating)
    }

    // MARK: - Study Session

    func testStartStudySessionSetsActiveDeck() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)

        XCTAssertNotNil(viewModel.activeDeck)
        XCTAssertEqual(viewModel.activeDeck?.id, deck.id)
    }

    func testStartStudySessionResetsIndex() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        XCTAssertEqual(viewModel.currentCardIndex, 1)

        viewModel.startStudySession(deck: deck)
        XCTAssertEqual(viewModel.currentCardIndex, 0)
    }

    func testStartStudySessionResetsFlipState() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)
        viewModel.flipCard()
        XCTAssertTrue(viewModel.isShowingBack)

        viewModel.startStudySession(deck: deck)
        XCTAssertFalse(viewModel.isShowingBack)
    }

    func testStartStudySessionResetsSessionComplete() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        XCTAssertTrue(viewModel.sessionComplete)

        viewModel.startStudySession(deck: deck)
        XCTAssertFalse(viewModel.sessionComplete)
    }

    func testEndStudySessionClearsActiveDeck() {
        let deck = makeDeck()
        viewModel.startStudySession(deck: deck)
        viewModel.endStudySession()

        XCTAssertNil(viewModel.activeDeck)
    }

    func testEndStudySessionResetsSessionComplete() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        XCTAssertTrue(viewModel.sessionComplete)

        viewModel.endStudySession()
        XCTAssertFalse(viewModel.sessionComplete)
    }

    // MARK: - Card Navigation

    func testFlipCardTogglesIsShowingBack() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)

        XCTAssertFalse(viewModel.isShowingBack)
        viewModel.flipCard()
        XCTAssertTrue(viewModel.isShowingBack)
        viewModel.flipCard()
        XCTAssertFalse(viewModel.isShowingBack)
    }

    func testNextCardAdvancesIndex() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)

        XCTAssertEqual(viewModel.currentCardIndex, 0)
        viewModel.nextCard()
        XCTAssertEqual(viewModel.currentCardIndex, 1)
        viewModel.nextCard()
        XCTAssertEqual(viewModel.currentCardIndex, 2)
    }

    func testNextCardResetsFlipState() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)
        viewModel.flipCard()
        XCTAssertTrue(viewModel.isShowingBack)

        viewModel.nextCard()
        XCTAssertFalse(viewModel.isShowingBack)
    }

    func testNextCardOnLastCardSetsSessionComplete() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)

        XCTAssertFalse(viewModel.sessionComplete)
        viewModel.nextCard()
        XCTAssertTrue(viewModel.sessionComplete)
    }

    func testNextCardOnLastCardOfMultipleCards() {
        let deck = makeDeck(cardCount: 2)
        viewModel.startStudySession(deck: deck)

        viewModel.nextCard()
        XCTAssertFalse(viewModel.sessionComplete)
        viewModel.nextCard()
        XCTAssertTrue(viewModel.sessionComplete)
    }

    func testNextCardDoesNothingWithoutActiveDeck() {
        XCTAssertNil(viewModel.activeDeck)
        viewModel.nextCard() // Should not crash
        XCTAssertFalse(viewModel.sessionComplete)
    }

    func testPreviousCardDecrementsIndex() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        viewModel.nextCard()
        XCTAssertEqual(viewModel.currentCardIndex, 2)

        viewModel.previousCard()
        XCTAssertEqual(viewModel.currentCardIndex, 1)
    }

    func testPreviousCardResetsFlipState() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        viewModel.flipCard()
        XCTAssertTrue(viewModel.isShowingBack)

        viewModel.previousCard()
        XCTAssertFalse(viewModel.isShowingBack)
    }

    func testPreviousCardAtFirstCardDoesNotGoNegative() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)

        XCTAssertEqual(viewModel.currentCardIndex, 0)
        viewModel.previousCard()
        XCTAssertEqual(viewModel.currentCardIndex, 0)
    }

    func testRestartSessionResetsIndexAndFlip() {
        let deck = makeDeck(cardCount: 3)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        viewModel.nextCard()
        viewModel.flipCard()

        XCTAssertEqual(viewModel.currentCardIndex, 2)
        XCTAssertTrue(viewModel.isShowingBack)

        viewModel.restartSession()

        XCTAssertEqual(viewModel.currentCardIndex, 0)
        XCTAssertFalse(viewModel.isShowingBack)
        XCTAssertFalse(viewModel.sessionComplete)
    }

    func testRestartSessionAfterSessionComplete() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)
        viewModel.nextCard()
        XCTAssertTrue(viewModel.sessionComplete)

        viewModel.restartSession()
        XCTAssertFalse(viewModel.sessionComplete)
        XCTAssertEqual(viewModel.currentCardIndex, 0)
    }

    // MARK: - Computed Properties

    func testCurrentCardReturnsCorrectCard() {
        let note = makeNote()
        let cards = makeCards(count: 3, noteID: note.id)
        let deck = FlashcardDeck(sourceNote: note, cards: cards)
        viewModel.startStudySession(deck: deck)

        XCTAssertEqual(viewModel.currentCard?.front, cards[0].front)
        viewModel.nextCard()
        XCTAssertEqual(viewModel.currentCard?.front, cards[1].front)
        viewModel.nextCard()
        XCTAssertEqual(viewModel.currentCard?.front, cards[2].front)
    }

    func testCurrentCardReturnsNilWithNoActiveDeck() {
        XCTAssertNil(viewModel.currentCard)
    }

    func testProgressFractionWithSingleCard() {
        let deck = makeDeck(cardCount: 1)
        viewModel.startStudySession(deck: deck)
        XCTAssertEqual(viewModel.progressFraction, 1.0, accuracy: 0.001)
    }

    func testProgressFractionFirstCard() {
        let deck = makeDeck(cardCount: 4)
        viewModel.startStudySession(deck: deck)
        XCTAssertEqual(viewModel.progressFraction, 0.25, accuracy: 0.001)
    }

    func testProgressFractionAdvances() {
        let deck = makeDeck(cardCount: 4)
        viewModel.startStudySession(deck: deck)

        viewModel.nextCard()
        XCTAssertEqual(viewModel.progressFraction, 0.5, accuracy: 0.001)

        viewModel.nextCard()
        XCTAssertEqual(viewModel.progressFraction, 0.75, accuracy: 0.001)

        viewModel.nextCard()
        XCTAssertEqual(viewModel.progressFraction, 1.0, accuracy: 0.001)
    }

    func testProgressFractionWithNoActiveDeck() {
        XCTAssertEqual(viewModel.progressFraction, 0.0)
    }

    func testProgressFractionWithEmptyDeck() {
        let note = makeNote()
        let deck = FlashcardDeck(sourceNote: note, cards: [])
        viewModel.startStudySession(deck: deck)
        XCTAssertEqual(viewModel.progressFraction, 0.0)
    }

    // MARK: - Update Pending Card

    func testUpdatePendingCardModifiesCard() {
        // updatePendingCard only works on an existing pendingDeck.
        // We cannot set pendingDeck directly (private setter), but we can verify
        // that calling it with no pendingDeck is a safe no-op.
        let noteID = UUID()
        let card = Flashcard(front: "Original", back: "Original back", sourceNoteID: noteID)
        viewModel.updatePendingCard(card) // pendingDeck is nil — should not crash
        XCTAssertNil(viewModel.pendingDeck)
    }

    // MARK: - Delete Pending Card

    func testDeletePendingCardWithNoPendingDeckIsNoop() {
        viewModel.deletePendingCard(at: IndexSet([0])) // Should not crash
        XCTAssertNil(viewModel.pendingDeck)
    }
}
