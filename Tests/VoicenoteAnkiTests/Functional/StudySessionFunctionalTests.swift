import XCTest
@testable import VoicenoteAnki

/// Functional tests that walk through a complete study session with real card
/// content. The CI pipeline fails if the session flow breaks.
@MainActor
final class StudySessionFunctionalTests: XCTestCase {

    // MARK: - Fixtures

    /// A realistic deck of 4 cards covering Swift concurrency.
    private func makeSwiftConcurrencyDeck() -> FlashcardDeck {
        let noteID = UUID()
        let note = VoiceNote(
            audioFileURL: URL(fileURLWithPath: "/tmp/swift_concurrency.m4a"),
            transcript: "Today we covered async/await, actors, and structured concurrency in Swift.",
            duration: 120.0
        )
        let cards: [Flashcard] = [
            Flashcard(
                front: "What keyword marks a function as asynchronous in Swift?",
                back: "async",
                tags: ["swift", "concurrency"],
                difficulty: .easy,
                sourceNoteID: noteID
            ),
            Flashcard(
                front: "How do you call an async function?",
                back: "Use 'await' before the call inside an async context.",
                tags: ["swift", "concurrency"],
                difficulty: .easy,
                sourceNoteID: noteID
            ),
            Flashcard(
                front: "What is an actor in Swift?",
                back: "A reference type that protects its mutable state from data races.",
                tags: ["swift", "concurrency", "actor"],
                difficulty: .medium,
                sourceNoteID: noteID
            ),
            Flashcard(
                front: "What is structured concurrency?",
                back: "A model where child tasks are scoped to their parent, "
                    + "ensuring all tasks complete before the parent exits.",
                tags: ["swift", "concurrency"],
                difficulty: .hard,
                sourceNoteID: noteID
            ),
        ]
        return FlashcardDeck(sourceNote: note, cards: cards)
    }

    // MARK: - Full session walk-through

    func testCompleteStudySessionFromStartToFinish() {
        let vm   = FlashcardsViewModel()
        let deck = makeSwiftConcurrencyDeck()

        // 1. Add the deck
        vm.confirmPendingDeck(deck)
        XCTAssertEqual(vm.decks.count, 1)

        // 2. Start session
        vm.startStudySession(deck: deck)
        XCTAssertEqual(vm.currentCardIndex, 0)
        XCTAssertFalse(vm.isShowingBack)
        XCTAssertFalse(vm.sessionComplete)

        // 3. Card 1: read question, flip to see answer
        XCTAssertEqual(vm.currentCard?.front,
                       "What keyword marks a function as asynchronous in Swift?")
        vm.flipCard()
        XCTAssertTrue(vm.isShowingBack)
        XCTAssertEqual(vm.currentCard?.back, "async")

        // 4. Advance to card 2
        vm.nextCard()
        XCTAssertEqual(vm.currentCardIndex, 1)
        XCTAssertFalse(vm.isShowingBack, "Flip state must reset on next card")
        XCTAssertEqual(vm.currentCard?.front, "How do you call an async function?")

        // 5. Advance to card 3 without flipping
        vm.nextCard()
        XCTAssertEqual(vm.currentCardIndex, 2)
        XCTAssertEqual(vm.currentCard?.front, "What is an actor in Swift?")

        // 6. Go back to card 2
        vm.previousCard()
        XCTAssertEqual(vm.currentCardIndex, 1)
        XCTAssertEqual(vm.currentCard?.front, "How do you call an async function?")

        // 7. Progress to the last card
        vm.nextCard() // → 2
        vm.nextCard() // → 3 (last)
        XCTAssertEqual(vm.currentCardIndex, 3)
        XCTAssertFalse(vm.sessionComplete)

        // 8. Advance past last card → session complete
        vm.nextCard()
        XCTAssertTrue(vm.sessionComplete)

        // 9. Restart
        vm.restartSession()
        XCTAssertEqual(vm.currentCardIndex, 0)
        XCTAssertFalse(vm.sessionComplete)
        XCTAssertFalse(vm.isShowingBack)
        XCTAssertEqual(vm.currentCard?.front,
                       "What keyword marks a function as asynchronous in Swift?")

        // 10. End session
        vm.endStudySession()
        XCTAssertNil(vm.activeDeck)
    }

    // MARK: - Progress fraction matches card position

    func testProgressFractionAtEachCardInDeck() {
        let vm   = FlashcardsViewModel()
        let deck = makeSwiftConcurrencyDeck()
        vm.startStudySession(deck: deck)

        let expected = [0.25, 0.50, 0.75, 1.0]
        for (index, expectedFraction) in expected.enumerated() {
            XCTAssertEqual(vm.progressFraction, expectedFraction, accuracy: 0.001,
                           "Wrong progress at card index \(index)")
            if index < expected.count - 1 { vm.nextCard() }
        }
    }

    // MARK: - Deck content is preserved after confirm

    func testConfirmedDeckCardContentIsIntact() {
        let vm   = FlashcardsViewModel()
        let deck = makeSwiftConcurrencyDeck()
        vm.confirmPendingDeck(deck)

        let saved = vm.decks.first!
        XCTAssertEqual(saved.cards.count, 4)
        XCTAssertEqual(saved.cards[0].front,
                       "What keyword marks a function as asynchronous in Swift?")
        XCTAssertEqual(saved.cards[0].back, "async")
        XCTAssertEqual(saved.cards[0].difficulty, .easy)
        XCTAssertEqual(saved.cards[2].difficulty, .medium)
        XCTAssertEqual(saved.cards[3].difficulty, .hard)
    }

    // MARK: - Deleting the deck during a session does not crash

    func testDeleteDeckAfterEndingSession() {
        let vm   = FlashcardsViewModel()
        let deck = makeSwiftConcurrencyDeck()
        vm.confirmPendingDeck(deck)
        vm.startStudySession(deck: deck)
        vm.endStudySession()

        vm.deleteDeck(at: IndexSet([0]))
        XCTAssertTrue(vm.decks.isEmpty)
        XCTAssertNil(vm.activeDeck)
    }
}
