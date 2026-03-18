import XCTest
@testable import VoicenoteAnki

/// Functional tests that exercise the full flashcard lifecycle with concrete,
/// hardcoded content. The CI pipeline fails if any assertion here does not hold.
final class FlashcardLifecycleTests: XCTestCase {

    // MARK: - Create a specific flashcard

    func testCreateTestFlashcard() {
        let noteID = UUID()
        let card = Flashcard(
            front: "This is a test",
            back: "This is a test answer",
            tags: ["test"],
            difficulty: .easy,
            sourceNoteID: noteID
        )

        XCTAssertEqual(card.front, "This is a test")
        XCTAssertEqual(card.back, "This is a test answer")
        XCTAssertEqual(card.tags, ["test"])
        XCTAssertEqual(card.difficulty, .easy)
        XCTAssertEqual(card.sourceNoteID, noteID)
    }

    // MARK: - Build a deck from concrete cards and verify ordering

    func testDeckContainsCardsInOrder() {
        let noteID = UUID()
        let note = VoiceNote(
            audioFileURL: URL(fileURLWithPath: "/tmp/lecture.m4a"),
            transcript: "Swift is a compiled language. Protocols define interfaces.",
            duration: 15.0
        )

        let cards: [Flashcard] = [
            Flashcard(front: "What is Swift?",
                      back: "A compiled, statically typed language by Apple.",
                      tags: ["swift", "language"],
                      difficulty: .easy,
                      sourceNoteID: noteID),
            Flashcard(front: "What is a protocol in Swift?",
                      back: "A blueprint of methods and properties that a type must implement.",
                      tags: ["swift", "protocol"],
                      difficulty: .medium,
                      sourceNoteID: noteID),
            Flashcard(front: "What does 'compiled' mean?",
                      back: "Source code is translated to machine code before execution.",
                      tags: ["cs-fundamentals"],
                      difficulty: .hard,
                      sourceNoteID: noteID),
        ]

        let deck = FlashcardDeck(sourceNote: note, cards: cards)

        XCTAssertEqual(deck.cards.count, 3)
        XCTAssertEqual(deck.cards[0].front, "What is Swift?")
        XCTAssertEqual(deck.cards[1].front, "What is a protocol in Swift?")
        XCTAssertEqual(deck.cards[2].front, "What does 'compiled' mean?")
    }

    // MARK: - Difficulty distribution in a deck

    func testDeckDifficultyDistribution() {
        let noteID = UUID()
        let note = VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a"))
        let cards: [Flashcard] = [
            Flashcard(front: "Easy Q",   back: "Easy A",   difficulty: .easy,   sourceNoteID: noteID),
            Flashcard(front: "Medium Q", back: "Medium A", difficulty: .medium, sourceNoteID: noteID),
            Flashcard(front: "Medium Q2",back: "Medium A2",difficulty: .medium, sourceNoteID: noteID),
            Flashcard(front: "Hard Q",   back: "Hard A",   difficulty: .hard,   sourceNoteID: noteID),
        ]
        let deck = FlashcardDeck(sourceNote: note, cards: cards)

        let easyCount   = deck.cards.filter { $0.difficulty == .easy }.count
        let mediumCount = deck.cards.filter { $0.difficulty == .medium }.count
        let hardCount   = deck.cards.filter { $0.difficulty == .hard }.count

        XCTAssertEqual(easyCount,   1)
        XCTAssertEqual(mediumCount, 2)
        XCTAssertEqual(hardCount,   1)
    }

    // MARK: - Tag filtering

    func testFilterCardsByTag() {
        let noteID = UUID()
        let note = VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a"))
        let cards: [Flashcard] = [
            Flashcard(front: "Q1", back: "A1", tags: ["swift"], sourceNoteID: noteID),
            Flashcard(front: "Q2", back: "A2", tags: ["swift", "ios"], sourceNoteID: noteID),
            Flashcard(front: "Q3", back: "A3", tags: ["cs-fundamentals"], sourceNoteID: noteID),
        ]
        let deck = FlashcardDeck(sourceNote: note, cards: cards)

        let swiftCards = deck.cards.filter { $0.tags.contains("swift") }
        XCTAssertEqual(swiftCards.count, 2)
        XCTAssertTrue(swiftCards.allSatisfy { $0.tags.contains("swift") })
    }

    // MARK: - Codable round-trip with concrete content

    func testFlashcardCodableRoundTripWithRealContent() throws {
        let noteID = UUID()
        let original = Flashcard(
            front: "What is the time complexity of binary search?",
            back: "O(log n)",
            tags: ["algorithms", "complexity"],
            difficulty: .medium,
            sourceNoteID: noteID
        )

        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Flashcard.self, from: data)

        XCTAssertEqual(decoded.front, "What is the time complexity of binary search?")
        XCTAssertEqual(decoded.back, "O(log n)")
        XCTAssertEqual(decoded.tags, ["algorithms", "complexity"])
        XCTAssertEqual(decoded.difficulty, .medium)
        XCTAssertEqual(decoded.id, original.id)
    }

    // MARK: - Flashcard mutation preserves identity

    func testEditingFlashcardContentPreservesID() {
        let noteID = UUID()
        var card = Flashcard(
            front: "Original question",
            back: "Original answer",
            sourceNoteID: noteID
        )
        let originalID = card.id

        card.front = "Updated question"
        card.back  = "Updated answer"

        XCTAssertEqual(card.id, originalID, "Editing content must not change the card's identity")
        XCTAssertEqual(card.front, "Updated question")
        XCTAssertEqual(card.back, "Updated answer")
    }
}
