import XCTest
@testable import VoicenoteAnki

final class FlashcardDeckTests: XCTestCase {

    private let testURL = URL(fileURLWithPath: "/tmp/test_note.m4a")

    // MARK: - Helpers

    private func makeNote(date: Date = .now) -> VoiceNote {
        VoiceNote(date: date, audioFileURL: testURL, transcript: "Test transcript")
    }

    private func makeCards(count: Int, noteID: UUID) -> [Flashcard] {
        (0..<count).map { i in
            Flashcard(front: "Q\(i)", back: "A\(i)", sourceNoteID: noteID)
        }
    }

    // MARK: - Initialization

    func testFlashcardDeckDefaultInitialization() {
        let note = makeNote()
        let cards = makeCards(count: 3, noteID: note.id)
        let before = Date()
        let deck = FlashcardDeck(sourceNote: note, cards: cards)
        let after = Date()

        XCTAssertEqual(deck.cards.count, 3)
        XCTAssertEqual(deck.sourceNote.id, note.id)
        XCTAssertFalse(deck.id.uuidString.isEmpty)
        XCTAssertTrue(deck.createdAt >= before && deck.createdAt <= after)
    }

    func testFlashcardDeckFullInitialization() {
        let id = UUID()
        let note = makeNote()
        let cards = makeCards(count: 2, noteID: note.id)
        let date = Date(timeIntervalSince1970: 0)
        let deck = FlashcardDeck(id: id, sourceNote: note, cards: cards, createdAt: date)

        XCTAssertEqual(deck.id, id)
        XCTAssertEqual(deck.cards.count, 2)
        XCTAssertEqual(deck.createdAt, date)
    }

    func testFlashcardDeckEmptyCards() {
        let note = makeNote()
        let deck = FlashcardDeck(sourceNote: note, cards: [])
        XCTAssertTrue(deck.cards.isEmpty)
    }

    // MARK: - Title

    func testDeckTitleHasNotePrefix() {
        let note = makeNote()
        let deck = FlashcardDeck(sourceNote: note, cards: [])
        XCTAssertTrue(deck.title.hasPrefix("Note — "), "Title should start with 'Note — ', got: \(deck.title)")
    }

    func testDeckTitleIncludesFormattedDate() {
        let date = Date(timeIntervalSince1970: 0) // Jan 1, 1970
        let note = makeNote(date: date)
        let deck = FlashcardDeck(sourceNote: note, cards: [])

        // Title should contain some date representation
        XCTAssertFalse(deck.title.isEmpty)
        XCTAssertTrue(deck.title.contains("Note — "))
    }

    func testDeckTitlesAreDifferentForDifferentDates() {
        let note1 = makeNote(date: Date(timeIntervalSince1970: 1_000_000))
        let note2 = makeNote(date: Date(timeIntervalSince1970: 2_000_000))
        let deck1 = FlashcardDeck(sourceNote: note1, cards: [])
        let deck2 = FlashcardDeck(sourceNote: note2, cards: [])
        XCTAssertNotEqual(deck1.title, deck2.title)
    }

    // MARK: - Mutation

    func testFlashcardDeckCardsMutation() {
        let note = makeNote()
        var deck = FlashcardDeck(sourceNote: note, cards: makeCards(count: 2, noteID: note.id))

        let newCard = Flashcard(front: "New Q", back: "New A", sourceNoteID: note.id)
        deck.cards.append(newCard)
        XCTAssertEqual(deck.cards.count, 3)

        deck.cards.removeLast()
        XCTAssertEqual(deck.cards.count, 2)
    }

    // MARK: - Unique IDs

    func testDecksHaveUniqueIds() {
        let note = makeNote()
        let deck1 = FlashcardDeck(sourceNote: note, cards: [])
        let deck2 = FlashcardDeck(sourceNote: note, cards: [])
        XCTAssertNotEqual(deck1.id, deck2.id)
    }
}
