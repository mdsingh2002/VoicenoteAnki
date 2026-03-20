import XCTest
@testable import VoicenoteAnki

// MARK: - Mock URLProtocol

/// Intercepts URLSession requests so tests can return canned responses without
/// hitting the real Anthropic API.
final class MockURLProtocol: URLProtocol {

    /// Set before each test to control the response.
    static var mockHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.mockHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Test Helpers

private func makeAnthropicResponse(text: String, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    let body: [String: Any] = [
        "content": [["type": "text", "text": text]]
    ]
    let data = try! JSONSerialization.data(withJSONObject: body)
    return (response, data)
}

private func makeAnthropicErrorResponse(message: String, statusCode: Int) -> (HTTPURLResponse, Data) {
    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    let body: [String: Any] = ["error": ["message": message]]
    let data = try! JSONSerialization.data(withJSONObject: body)
    return (response, data)
}

private let validCardsJSON = """
[
  {"front":"What is photosynthesis?","back":"The process by which plants make food using sunlight.","tags":["biology","plants"],"difficulty":"easy"},
  {"front":"What is mitosis?","back":"Cell division producing two identical daughter cells.","tags":["biology","cells"],"difficulty":"medium"}
]
"""

// MARK: - FlashcardGenerationServiceTests

final class FlashcardGenerationServiceTests: XCTestCase {

    private var service: FlashcardGenerationService!
    private var mockSession: URLSession!

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        // Register our mock protocol so URLSession uses it
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        service = FlashcardGenerationService(session: mockSession)
        MockURLProtocol.mockHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.mockHandler = nil
        service = nil
        mockSession = nil
        super.tearDown()
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

    // MARK: - Response parsing (via MockURLProtocol)
    //
    // These tests inject a fake URLSession via MockURLProtocol and set up the
    // load balancer directly (avoiding the async Task indirection of setting
    // FlashcardGenerationService.apiKey).

    private func useTestKey() async {
        await FlashcardGenerationService.loadBalancer.setKeys(["sk-test-key"])
    }

    private func clearTestKey() async {
        await FlashcardGenerationService.loadBalancer.setKeys([])
    }

    func testSuccessfulResponseReturnsFlashcards() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: validCardsJSON) }

        let cards = try await service.generateFlashcards(from: "Biology lecture", noteID: UUID())
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards[0].front, "What is photosynthesis?")
        XCTAssertEqual(cards[0].back, "The process by which plants make food using sunlight.")
        XCTAssertEqual(cards[0].difficulty, .easy)
        XCTAssertEqual(cards[0].tags, ["biology", "plants"])
        XCTAssertEqual(cards[1].front, "What is mitosis?")
        XCTAssertEqual(cards[1].difficulty, .medium)
    }

    func testResponseCardsHaveCorrectSourceNoteID() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: validCardsJSON) }

        let noteID = UUID()
        let cards = try await service.generateFlashcards(from: "Some transcript", noteID: noteID)
        for card in cards {
            XCTAssertEqual(card.sourceNoteID, noteID)
        }
    }

    func testResponseWithMarkdownFencesIsParsedCorrectly() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        let fencedJSON = "```json\n\(validCardsJSON)\n```"
        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: fencedJSON) }

        let cards = try await service.generateFlashcards(from: "Biology lecture", noteID: UUID())
        XCTAssertEqual(cards.count, 2)
    }

    func testResponseWithUnfencedMarkdownIsParsedCorrectly() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        let fencedJSON = "```\n\(validCardsJSON)\n```"
        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: fencedJSON) }

        let cards = try await service.generateFlashcards(from: "Lecture notes", noteID: UUID())
        XCTAssertEqual(cards.count, 2)
    }

    func testUnknownDifficultyFallsBackToMedium() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        let json = """
        [{"front":"Q","back":"A","tags":[],"difficulty":"unknown-value"}]
        """
        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: json) }

        let cards = try await service.generateFlashcards(from: "Notes", noteID: UUID())
        XCTAssertEqual(cards.first?.difficulty, .medium)
    }

    func testHardDifficultyIsParsedCorrectly() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        let json = """
        [{"front":"Hard Q","back":"Hard A","tags":["topic"],"difficulty":"hard"}]
        """
        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: json) }

        let cards = try await service.generateFlashcards(from: "Notes", noteID: UUID())
        XCTAssertEqual(cards.first?.difficulty, .hard)
    }

    func testHTTP500ResponseThrowsAPIError() async {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        MockURLProtocol.mockHandler = { _ in
            makeAnthropicErrorResponse(message: "Internal server error", statusCode: 500)
        }

        do {
            _ = try await service.generateFlashcards(from: "Some transcript", noteID: UUID())
            XCTFail("Expected an error")
        } catch let error as FlashcardGenerationError {
            if case .apiError = error { /* expected */ } else {
                XCTFail("Expected .apiError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testHTTP401ResponseThrowsAPIError() async {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        MockURLProtocol.mockHandler = { _ in
            makeAnthropicErrorResponse(message: "Invalid API key", statusCode: 401)
        }

        do {
            _ = try await service.generateFlashcards(from: "Some transcript", noteID: UUID())
            XCTFail("Expected an error")
        } catch let error as FlashcardGenerationError {
            if case .apiError(let msg) = error {
                XCTAssertTrue(msg.contains("Invalid API key"))
            } else {
                XCTFail("Expected .apiError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMalformedInnerJSONThrowsDecodingError() async {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        // The outer Anthropic response is valid, but the flashcard JSON inside is malformed
        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: "this is not JSON") }

        do {
            _ = try await service.generateFlashcards(from: "Lecture", noteID: UUID())
            XCTFail("Expected an error")
        } catch let error as FlashcardGenerationError {
            if case .decodingError = error { /* expected */ } else {
                XCTFail("Expected .decodingError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMalformedOuterResponseThrowsDecodingError() async {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        MockURLProtocol.mockHandler = { _ in (response, Data("not valid json at all".utf8)) }

        do {
            _ = try await service.generateFlashcards(from: "Lecture", noteID: UUID())
            XCTFail("Expected an error")
        } catch let error as FlashcardGenerationError {
            if case .decodingError = error { /* expected */ } else {
                XCTFail("Expected .decodingError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEmptyCardsArrayIsValidResponse() async throws {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        MockURLProtocol.mockHandler = { _ in makeAnthropicResponse(text: "[]") }

        let cards = try await service.generateFlashcards(from: "Quiet lecture", noteID: UUID())
        XCTAssertTrue(cards.isEmpty)
    }

    func testResponseWithNoTextContentThrowsInvalidResponse() async {
        await useTestKey()
        defer { Task { await self.clearTestKey() } }

        // Valid outer response but content array has no text items
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let body: [String: Any] = ["content": []]
        let data = try! JSONSerialization.data(withJSONObject: body)
        MockURLProtocol.mockHandler = { _ in (response, data) }

        do {
            _ = try await service.generateFlashcards(from: "Lecture", noteID: UUID())
            XCTFail("Expected an error")
        } catch let error as FlashcardGenerationError {
            if case .invalidResponse = error { /* expected */ } else {
                XCTFail("Expected .invalidResponse, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
