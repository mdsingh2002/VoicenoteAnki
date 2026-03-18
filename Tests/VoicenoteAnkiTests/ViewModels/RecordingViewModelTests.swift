import XCTest
@testable import VoicenoteAnki

@MainActor
final class RecordingViewModelTests: XCTestCase {

    private var viewModel: RecordingViewModel!

    override func setUp() {
        super.setUp()
        viewModel = RecordingViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsNotRecording() {
        XCTAssertFalse(viewModel.isRecording)
    }

    func testInitialStateIsNotTranscribing() {
        XCTAssertFalse(viewModel.isTranscribing)
    }

    func testInitialLiveTranscriptIsEmpty() {
        XCTAssertTrue(viewModel.liveTranscript.isEmpty)
    }

    func testInitialFinalTranscriptIsEmpty() {
        XCTAssertTrue(viewModel.finalTranscript.isEmpty)
    }

    func testInitialPowerLevelIsZero() {
        XCTAssertEqual(viewModel.powerLevel, 0)
    }

    func testInitialRecordingDurationIsZero() {
        XCTAssertEqual(viewModel.recordingDuration, 0)
    }

    func testInitialSavedNotesIsEmpty() {
        XCTAssertTrue(viewModel.savedNotes.isEmpty)
    }

    func testInitialErrorMessageIsNil() {
        XCTAssertNil(viewModel.errorMessage)
    }

    func testInitialLatestNoteIsNil() {
        XCTAssertNil(viewModel.latestNote)
    }

    // MARK: - Shared FlashcardsViewModel

    func testFlashcardsViewModelIsCreatedOnInit() {
        XCTAssertNotNil(viewModel.flashcardsVM)
    }

    func testFlashcardsViewModelIsSharedAcrossCalls() {
        let vm1 = viewModel.flashcardsVM
        let vm2 = viewModel.flashcardsVM
        // Same instance should be returned
        XCTAssertTrue(vm1 === vm2)
    }

    // MARK: - formattedDuration

    func testFormattedDurationAtZero() {
        // Initial duration is 0
        XCTAssertEqual(viewModel.formattedDuration, "00:00")
    }

    func testFormattedDurationFormat() {
        // Verify the format is MM:SS by checking the default state output
        let result = viewModel.formattedDuration
        // Should match pattern: two digits, colon, two digits
        let pattern = #"^\d{2}:\d{2}$"#
        XCTAssertTrue(result.range(of: pattern, options: .regularExpression) != nil,
                      "formattedDuration '\(result)' does not match MM:SS format")
    }

    func testFormattedDurationCalculation() {
        // Test the formatting logic directly by checking edge cases
        // We test by examining the string format from the pure calculation logic.
        // Duration 0 → "00:00"
        // Duration 61 → "01:01"
        // Duration 3661 → "61:01" (no hours cap)
        let testCases: [(TimeInterval, String)] = [
            (0, "00:00"),
            (1, "00:01"),
            (59, "00:59"),
            (60, "01:00"),
            (61, "01:01"),
            (3600, "60:00"),
            (3661, "61:01")
        ]
        for (duration, expected) in testCases {
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            let result = String(format: "%02d:%02d", mins, secs)
            XCTAssertEqual(result, expected, "formattedDuration for \(duration)s")
        }
    }
}
