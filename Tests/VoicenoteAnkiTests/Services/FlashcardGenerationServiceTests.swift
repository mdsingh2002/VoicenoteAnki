import XCTest
@testable import VoicenoteAnki

final class FlashcardGenerationServiceTests: XCTestCase {

    private let service = FlashcardGenerationService()

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        // Ensure no real API key leaks into tests that check for missing key
        // We save and restore the original key
    }

    // MARK: - Empty transcript guard

    func testEmptyTranscriptThrowsEmptyTranscriptError() async {
        do {
            _ = try await service.generateFlashcards(from: "", noteID: UUID())
            XCTFail("Expected FlashcardGenerationError.emptyTranscript to be thrown")
        } catch let error as FlashcardGenerationError {
            guard case .emptyTranscript = error else {
                XCTFail("Expected .emptyTranscript, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWhitespaceOnlyTranscriptThrowsEmptyTranscriptError() async {
        do {
            _ = try await service.generateFlashcards(from: "   \n\t   ", noteID: UUID())
            XCTFail("Expected FlashcardGenerationError.emptyTranscript to be thrown")
        } catch let error as FlashcardGenerationError {
            guard case .emptyTranscript = error else {
                XCTFail("Expected .emptyTranscript, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testNewlineOnlyTranscriptThrowsEmptyTranscriptError() async {
        do {
            _ = try await service.generateFlashcards(from: "\n\n\n", noteID: UUID())
            XCTFail("Expected FlashcardGenerationError.emptyTranscript to be thrown")
        } catch let error as FlashcardGenerationError {
            guard case .emptyTranscript = error else {
                XCTFail("Expected .emptyTranscript, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Missing API key guard

    func testMissingAPIKeyThrowsMissingAPIKeyError() async {
        let savedKey = FlashcardGenerationService.apiKey
        FlashcardGenerationService.apiKey = ""
        defer { FlashcardGenerationService.apiKey = savedKey }

        do {
            _ = try await service.generateFlashcards(from: "Valid transcript with content", noteID: UUID())
            XCTFail("Expected FlashcardGenerationError.missingAPIKey to be thrown")
        } catch let error as FlashcardGenerationError {
            guard case .missingAPIKey = error else {
                XCTFail("Expected .missingAPIKey, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testWhitespaceOnlyAPIKeyThrowsMissingAPIKeyError() async {
        let savedKey = FlashcardGenerationService.apiKey
        FlashcardGenerationService.apiKey = "   "
        defer { FlashcardGenerationService.apiKey = savedKey }

        do {
            _ = try await service.generateFlashcards(from: "Valid transcript with content", noteID: UUID())
            XCTFail("Expected FlashcardGenerationError.missingAPIKey to be thrown")
        } catch let error as FlashcardGenerationError {
            guard case .missingAPIKey = error else {
                XCTFail("Expected .missingAPIKey, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Error precedence (empty transcript checked before API key)

    func testEmptyTranscriptCheckedBeforeAPIKey() async {
        let savedKey = FlashcardGenerationService.apiKey
        FlashcardGenerationService.apiKey = ""
        defer { FlashcardGenerationService.apiKey = savedKey }

        do {
            _ = try await service.generateFlashcards(from: "", noteID: UUID())
            XCTFail("Expected an error")
        } catch let error as FlashcardGenerationError {
            // emptyTranscript is checked first in the implementation
            guard case .emptyTranscript = error else {
                XCTFail("Expected .emptyTranscript (checked before .missingAPIKey), got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Error descriptions

    func testMissingAPIKeyErrorHasDescription() {
        let error = FlashcardGenerationError.missingAPIKey
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testEmptyTranscriptErrorHasDescription() {
        let error = FlashcardGenerationError.emptyTranscript
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testInvalidResponseErrorHasDescription() {
        let error = FlashcardGenerationError.invalidResponse
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testNetworkErrorIncludesUnderlyingDescription() {
        let underlying = URLError(.notConnectedToInternet)
        let error = FlashcardGenerationError.networkError(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network error"))
    }

    func testAPIErrorIncludesMessage() {
        let error = FlashcardGenerationError.apiError("Rate limit exceeded")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Rate limit exceeded"))
    }

    func testDecodingErrorHasDescription() {
        let underlying = DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Bad JSON")
        )
        let error = FlashcardGenerationError.decodingError(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    // MARK: - LocalizedError conformance

    func testAllErrorCasesAreLocalizedErrors() {
        let errors: [FlashcardGenerationError] = [
            .missingAPIKey,
            .emptyTranscript,
            .networkError(URLError(.timedOut)),
            .invalidResponse,
            .decodingError(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))),
            .apiError("some error")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "errorDescription should not be nil for \(error)")
        }
    }
}
