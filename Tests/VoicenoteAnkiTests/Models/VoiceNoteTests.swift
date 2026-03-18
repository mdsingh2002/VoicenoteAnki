import XCTest
@testable import VoicenoteAnki

final class VoiceNoteTests: XCTestCase {

    private let testURL = URL(fileURLWithPath: "/tmp/test_note.m4a")

    // MARK: - Initialization

    func testVoiceNoteDefaultInitialization() {
        let before = Date()
        let note = VoiceNote(audioFileURL: testURL)
        let after = Date()

        XCTAssertEqual(note.audioFileURL, testURL)
        XCTAssertEqual(note.transcript, "")
        XCTAssertEqual(note.duration, 0)
        XCTAssertFalse(note.id.uuidString.isEmpty)
        XCTAssertTrue(note.date >= before && note.date <= after)
    }

    func testVoiceNoteFullInitialization() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let note = VoiceNote(
            id: id,
            date: date,
            audioFileURL: testURL,
            transcript: "Hello world",
            duration: 42.5
        )

        XCTAssertEqual(note.id, id)
        XCTAssertEqual(note.date, date)
        XCTAssertEqual(note.audioFileURL, testURL)
        XCTAssertEqual(note.transcript, "Hello world")
        XCTAssertEqual(note.duration, 42.5, accuracy: 0.001)
    }

    func testVoiceNoteUniqueIDs() {
        let note1 = VoiceNote(audioFileURL: testURL)
        let note2 = VoiceNote(audioFileURL: testURL)
        XCTAssertNotEqual(note1.id, note2.id)
    }

    // MARK: - Mutation

    func testVoiceNoteTranscriptMutation() {
        var note = VoiceNote(audioFileURL: testURL)
        note.transcript = "Updated transcript"
        XCTAssertEqual(note.transcript, "Updated transcript")
    }

    func testVoiceNoteDurationMutation() {
        var note = VoiceNote(audioFileURL: testURL)
        note.duration = 123.45
        XCTAssertEqual(note.duration, 123.45, accuracy: 0.001)
    }

    // MARK: - Identifiable

    func testVoiceNoteIdentifiable() {
        let id = UUID()
        let note = VoiceNote(id: id, audioFileURL: testURL)
        XCTAssertEqual(note.id, id)
    }
}
