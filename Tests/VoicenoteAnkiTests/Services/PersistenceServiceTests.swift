import XCTest
@testable import VoicenoteAnki

final class PersistenceServiceTests: XCTestCase {

    private var persistence: PersistenceService!
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        // Use a fresh temp directory for each test to avoid cross-test pollution.
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        persistence = PersistenceService(directoryURL: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        persistence = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeNote() -> VoiceNote {
        VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a"), transcript: "Hello world")
    }

    private func makeDeck(cardCount: Int = 2) -> FlashcardDeck {
        let note = makeNote()
        let cards = (0..<cardCount).map { i in
            Flashcard(front: "Q\(i)", back: "A\(i)", tags: ["tag"], difficulty: .medium, sourceNoteID: note.id)
        }
        return FlashcardDeck(sourceNote: note, cards: cards)
    }

    // MARK: - Load

    func testLoadReturnsEmptyArrayWhenNoFileExists() throws {
        let decks = try persistence.load()
        XCTAssertTrue(decks.isEmpty)
    }

    // MARK: - Save & Load Round-trip

    func testSaveAndLoadRoundTrip() throws {
        let deck = makeDeck()
        try persistence.save([deck])

        let loaded = try persistence.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, deck.id)
    }

    func testSaveAndLoadPreservesCardContent() throws {
        let deck = makeDeck(cardCount: 3)
        try persistence.save([deck])

        let loaded = try persistence.load()
        let loadedCards = loaded[0].cards
        XCTAssertEqual(loadedCards.count, deck.cards.count)
        for (original, restored) in zip(deck.cards, loadedCards) {
            XCTAssertEqual(restored.id, original.id)
            XCTAssertEqual(restored.front, original.front)
            XCTAssertEqual(restored.back, original.back)
            XCTAssertEqual(restored.difficulty, original.difficulty)
            XCTAssertEqual(restored.tags, original.tags)
        }
    }

    func testSaveAndLoadPreservesMultipleDecks() throws {
        let deck1 = makeDeck()
        let deck2 = makeDeck(cardCount: 5)
        try persistence.save([deck1, deck2])

        let loaded = try persistence.load()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, deck1.id)
        XCTAssertEqual(loaded[1].id, deck2.id)
    }

    func testSaveEmptyArrayClearsPersistedDecks() throws {
        let deck = makeDeck()
        try persistence.save([deck])
        try persistence.save([])

        let loaded = try persistence.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveOverwritesPreviousData() throws {
        let deck1 = makeDeck()
        try persistence.save([deck1])

        let deck2 = makeDeck(cardCount: 5)
        try persistence.save([deck2])

        let loaded = try persistence.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, deck2.id)
    }

    // MARK: - VoiceNote metadata

    func testSaveAndLoadPreservesNoteTranscript() throws {
        let note = VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/a.m4a"), transcript: "Detailed transcript")
        let deck = FlashcardDeck(sourceNote: note, cards: [])
        try persistence.save([deck])

        let loaded = try persistence.load()
        XCTAssertEqual(loaded[0].sourceNote.transcript, "Detailed transcript")
    }

    // MARK: - Difficulty preservation

    func testSaveAndLoadPreservesDifficulty() throws {
        let note = makeNote()
        let cards = [
            Flashcard(front: "Easy Q", back: "Easy A", difficulty: .easy, sourceNoteID: note.id),
            Flashcard(front: "Hard Q", back: "Hard A", difficulty: .hard, sourceNoteID: note.id)
        ]
        let deck = FlashcardDeck(sourceNote: note, cards: cards)
        try persistence.save([deck])

        let loaded = try persistence.load()
        XCTAssertEqual(loaded[0].cards[0].difficulty, .easy)
        XCTAssertEqual(loaded[0].cards[1].difficulty, .hard)
    }
}
