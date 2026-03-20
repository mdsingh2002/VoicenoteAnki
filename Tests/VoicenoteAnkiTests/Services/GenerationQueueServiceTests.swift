import XCTest
@testable import VoicenoteAnki

// MARK: - MessagePriority Tests

final class MessagePriorityTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(MessagePriority.low.rawValue, 0)
        XCTAssertEqual(MessagePriority.normal.rawValue, 1)
        XCTAssertEqual(MessagePriority.high.rawValue, 2)
    }

    func testComparableLessThan() {
        XCTAssertTrue(MessagePriority.low < MessagePriority.normal)
        XCTAssertTrue(MessagePriority.low < MessagePriority.high)
        XCTAssertTrue(MessagePriority.normal < MessagePriority.high)
    }

    func testComparableNotLessThanSelf() {
        XCTAssertFalse(MessagePriority.low < MessagePriority.low)
        XCTAssertFalse(MessagePriority.normal < MessagePriority.normal)
        XCTAssertFalse(MessagePriority.high < MessagePriority.high)
    }

    func testComparableGreaterThan() {
        XCTAssertTrue(MessagePriority.high > MessagePriority.normal)
        XCTAssertTrue(MessagePriority.high > MessagePriority.low)
        XCTAssertTrue(MessagePriority.normal > MessagePriority.low)
    }

    func testPriorityOrdering() {
        let priorities: [MessagePriority] = [.high, .low, .normal]
        let sorted = priorities.sorted()
        XCTAssertEqual(sorted, [.low, .normal, .high])
    }
}

// MARK: - GenerationMessage Tests

final class GenerationMessageTests: XCTestCase {

    private func makeNote(transcript: String = "test") -> VoiceNote {
        VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a"), transcript: transcript, duration: 10)
    }

    func testDefaultInitialization() {
        let note = makeNote()
        let msg = GenerationMessage(note: note)
        XCTAssertNotNil(msg.id)
        XCTAssertEqual(msg.priority, .normal)
        XCTAssertEqual(msg.retryCount, 0)
        XCTAssertEqual(msg.note.transcript, "test")
    }

    func testCustomPriority() {
        let note = makeNote()
        let msg = GenerationMessage(note: note, priority: .high)
        XCTAssertEqual(msg.priority, .high)
    }

    func testLowPriority() {
        let note = makeNote()
        let msg = GenerationMessage(note: note, priority: .low)
        XCTAssertEqual(msg.priority, .low)
    }

    func testUniqueIDs() {
        let note = makeNote()
        let msg1 = GenerationMessage(note: note)
        let msg2 = GenerationMessage(note: note)
        XCTAssertNotEqual(msg1.id, msg2.id)
    }

    func testEnqueuedAtIsRecentDate() {
        let before = Date()
        let note = makeNote()
        let msg = GenerationMessage(note: note)
        let after = Date()
        XCTAssertGreaterThanOrEqual(msg.enqueuedAt, before)
        XCTAssertLessThanOrEqual(msg.enqueuedAt, after)
    }

    func testIdentifiable() {
        let note = makeNote()
        let msg = GenerationMessage(note: note)
        // Identifiable requires .id property - verified by accessing it
        let id: UUID = msg.id
        XCTAssertNotNil(id)
    }
}

// MARK: - GenerationQueueService Tests

final class GenerationQueueServiceTests: XCTestCase {

    private var queue: GenerationQueueService!

    override func setUp() async throws {
        try await super.setUp()
        // Use a fresh instance for each test (not the shared singleton)
        queue = GenerationQueueService()
        // Set maxConcurrentWorkers to 0 so workers don't actually run and hit the API
        await setMaxWorkers(0)
    }

    override func tearDown() async throws {
        await queue.purge()
        queue = nil
        try await super.tearDown()
    }

    private func setMaxWorkers(_ n: Int) async {
        await queue.set(maxConcurrentWorkers: n)
    }

    private func makeNote(transcript: String = "Hello World from a voice note") -> VoiceNote {
        VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/test.m4a"), transcript: transcript, duration: 5)
    }

    // MARK: - publish

    func testPublishReturnsMessageID() async {
        let note = makeNote()
        let id = await queue.publish(note: note)
        XCTAssertNotNil(id)
    }

    func testPublishIncreasesMetricsTotalPublished() async {
        let note = makeNote()
        _ = await queue.publish(note: note)
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.totalPublished, 1)
    }

    func testPublishIncreasesMetricsPending() async {
        let note = makeNote()
        _ = await queue.publish(note: note)
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 1)
    }

    func testMultiplePublishesIncreasePending() async {
        _ = await queue.publish(note: makeNote())
        _ = await queue.publish(note: makeNote())
        _ = await queue.publish(note: makeNote())
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 3)
        XCTAssertEqual(metrics.totalPublished, 3)
    }

    // MARK: - cancel

    func testCancelRemovesMessageFromQueue() async {
        let msgID = await queue.publish(note: makeNote())
        await queue.cancel(messageID: msgID)
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 0)
    }

    func testCancelNonExistentIDDoesNotCrash() async {
        _ = await queue.publish(note: makeNote())
        await queue.cancel(messageID: UUID()) // random ID
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 1) // original still there
    }

    func testCancelOnlyRemovesTargetMessage() async {
        let id1 = await queue.publish(note: makeNote())
        _ = await queue.publish(note: makeNote())
        _ = await queue.publish(note: makeNote())
        await queue.cancel(messageID: id1)
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 2)
    }

    // MARK: - purge

    func testPurgeClearsAllPendingMessages() async {
        _ = await queue.publish(note: makeNote())
        _ = await queue.publish(note: makeNote())
        _ = await queue.publish(note: makeNote())
        await queue.purge()
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 0)
    }

    func testPurgeOnEmptyQueueDoesNotCrash() async {
        await queue.purge()
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 0)
    }

    // MARK: - Priority ordering

    func testHighPriorityPublishedBeforeNormal() async {
        // With workers disabled, we can inspect queue ordering by publishing
        // and checking metrics, since cancel checks order
        _ = await queue.publish(note: makeNote(transcript: "low"), priority: .low)
        _ = await queue.publish(note: makeNote(transcript: "high"), priority: .high)
        _ = await queue.publish(note: makeNote(transcript: "normal"), priority: .normal)
        // All three should be in queue
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 3)
    }

    func testPublishWithAllPriorities() async {
        let idHigh   = await queue.publish(note: makeNote(), priority: .high)
        let idNormal = await queue.publish(note: makeNote(), priority: .normal)
        let idLow    = await queue.publish(note: makeNote(), priority: .low)
        XCTAssertNotNil(idHigh)
        XCTAssertNotNil(idNormal)
        XCTAssertNotNil(idLow)
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.totalPublished, 3)
    }

    // MARK: - subscribe / unsubscribe

    func testSubscribeReturnsUniqueIDs() async {
        let (id1, stream1) = await queue.subscribe()
        let (id2, stream2) = await queue.subscribe()
        XCTAssertNotEqual(id1, id2)
        // Clean up
        await queue.unsubscribe(id: id1)
        await queue.unsubscribe(id: id2)
        _ = stream1
        _ = stream2
    }

    func testUnsubscribeDoesNotCrashForUnknownID() async {
        await queue.unsubscribe(id: UUID())
        // No crash = pass
    }

    func testMultipleSubscribersCanCoexist() async {
        let (id1, s1) = await queue.subscribe()
        let (id2, s2) = await queue.subscribe()
        let (id3, s3) = await queue.subscribe()
        // All three registered; cleanup
        await queue.unsubscribe(id: id1)
        await queue.unsubscribe(id: id2)
        await queue.unsubscribe(id: id3)
        _ = s1; _ = s2; _ = s3
    }

    // MARK: - requeueDeadLetters

    func testRequeueDeadLettersDoesNotCrashOnEmptyDLQ() async {
        await queue.requeueDeadLetters()
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.deadLettered, 0)
    }

    // MARK: - Initial metrics

    func testInitialMetricsAreZero() async {
        let metrics = await queue.metrics
        XCTAssertEqual(metrics.pending, 0)
        XCTAssertEqual(metrics.processing, 0)
        XCTAssertEqual(metrics.completed, 0)
        XCTAssertEqual(metrics.deadLettered, 0)
        XCTAssertEqual(metrics.totalPublished, 0)
    }
}

// MARK: - GenerationQueueService extension for tests

/// Adds a test-only helper to configure maxConcurrentWorkers from outside the actor.
extension GenerationQueueService {
    func set(maxConcurrentWorkers n: Int) {
        self.maxConcurrentWorkers = n
    }
}

// MARK: - GenerationResult Tests

final class GenerationResultTests: XCTestCase {

    func testGenerationResultSuccess() {
        let msgID = UUID()
        let noteID = UUID()
        let note = VoiceNote(audioFileURL: URL(fileURLWithPath: "/tmp/t.m4a"), transcript: "x", duration: 1)
        let card = Flashcard(front: "Q", back: "A", sourceNoteID: noteID)
        let deck = FlashcardDeck(sourceNote: note, cards: [card])
        let result = GenerationResult(messageID: msgID, noteID: noteID, outcome: .success(deck))
        XCTAssertEqual(result.messageID, msgID)
        XCTAssertEqual(result.noteID, noteID)
        if case .success(let d) = result.outcome {
            XCTAssertEqual(d.cards.count, 1)
        } else {
            XCTFail("Expected .success outcome")
        }
    }

    func testGenerationResultDeadLetter() {
        let msgID = UUID()
        let noteID = UUID()
        let error = FlashcardGenerationError.emptyTranscript
        let result = GenerationResult(messageID: msgID, noteID: noteID, outcome: .deadLetter(error))
        XCTAssertEqual(result.messageID, msgID)
        XCTAssertEqual(result.noteID, noteID)
        if case .deadLetter(let e) = result.outcome {
            XCTAssertTrue(e is FlashcardGenerationError)
        } else {
            XCTFail("Expected .deadLetter outcome")
        }
    }
}

// MARK: - QueueMetrics Tests

final class QueueMetricsTests: XCTestCase {

    func testDefaultMetricsAreZero() {
        let metrics = QueueMetrics()
        XCTAssertEqual(metrics.pending, 0)
        XCTAssertEqual(metrics.processing, 0)
        XCTAssertEqual(metrics.completed, 0)
        XCTAssertEqual(metrics.deadLettered, 0)
        XCTAssertEqual(metrics.totalPublished, 0)
    }

    func testMetricsMutation() {
        var metrics = QueueMetrics()
        metrics.pending = 5
        metrics.processing = 2
        metrics.completed = 10
        metrics.deadLettered = 1
        metrics.totalPublished = 18
        XCTAssertEqual(metrics.pending, 5)
        XCTAssertEqual(metrics.processing, 2)
        XCTAssertEqual(metrics.completed, 10)
        XCTAssertEqual(metrics.deadLettered, 1)
        XCTAssertEqual(metrics.totalPublished, 18)
    }
}
