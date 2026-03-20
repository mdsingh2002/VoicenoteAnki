import Foundation

// MARK: - Message Priority (RabbitMQ-style priority queue levels 0–2)

enum MessagePriority: Int, Comparable {
    case low    = 0
    case normal = 1
    case high   = 2

    static func < (lhs: MessagePriority, rhs: MessagePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Generation Message (analogous to an AMQP message with headers)

struct GenerationMessage: Identifiable {
    let id: UUID
    let note: VoiceNote
    let priority: MessagePriority
    let enqueuedAt: Date
    var retryCount: Int = 0

    init(note: VoiceNote, priority: MessagePriority = .normal) {
        self.id         = UUID()
        self.note       = note
        self.priority   = priority
        self.enqueuedAt = Date()
    }
}

// MARK: - Generation Result (delivered to consumers after processing)

struct GenerationResult {
    let messageID: UUID
    let noteID: UUID
    let outcome: GenerationOutcome
}

enum GenerationOutcome {
    /// Flashcard generation succeeded.
    case success(FlashcardDeck)
    /// All delivery attempts failed; message was routed to the dead-letter queue.
    case deadLetter(Error)
}

// MARK: - Queue Metrics (observable broker statistics)

struct QueueMetrics {
    var pending: Int      = 0   // Messages waiting in the main queue
    var processing: Int   = 0   // Messages currently being processed by workers
    var completed: Int    = 0   // Successfully processed messages (lifetime)
    var deadLettered: Int = 0   // Messages in the dead-letter queue
    var totalPublished: Int = 0 // Total messages ever published (lifetime)
}

// MARK: - GenerationQueueService

/// RabbitMQ-inspired message broker for async flashcard generation.
///
/// Architecture mapping:
/// - `publish(note:priority:)` → AMQP `basic.publish` to a priority exchange
/// - `subscribe()`             → AMQP `basic.consume` returning an `AsyncStream`
/// - `mainQueue`               → durable priority queue
/// - `deadLetterQueue`         → dead-letter queue (DLQ) after max delivery attempts
/// - `maxConcurrentWorkers`    → consumer prefetch / QoS count
/// - `maxDeliveryAttempts`     → per-message delivery limit before dead-lettering
///
/// Thread safety is guaranteed by the Swift `actor` model.
actor GenerationQueueService {

    // MARK: - Shared Instance

    static let shared = GenerationQueueService()

    // MARK: - Configuration (tune like RabbitMQ queue arguments)

    /// Maximum parallel generation workers (analogous to `prefetch_count`).
    var maxConcurrentWorkers: Int = 2

    /// Maximum delivery attempts per message before routing to the DLQ.
    var maxDeliveryAttempts: Int = 3

    /// Exponential-backoff base (seconds). Retry delay = base × 2^(attempt-1).
    var retryBaseDelay: TimeInterval = 2.0

    // MARK: - Internal State

    private var mainQueue:       [GenerationMessage] = []  // Priority-sorted
    private var deadLetterQueue: [GenerationMessage] = []
    private var activeWorkers: Int = 0
    private(set) var metrics = QueueMetrics()

    private let generationService = FlashcardGenerationService()

    /// Result subscribers – keyed by subscriber UUID (like AMQP consumer tags).
    private var subscribers: [UUID: AsyncStream<GenerationResult>.Continuation] = [:]

    // MARK: - Publisher API

    /// Publish a voice note for flashcard generation.
    ///
    /// Messages with higher priority are processed before lower-priority ones.
    /// Returns a message ID that can be used for cancellation.
    @discardableResult
    func publish(note: VoiceNote, priority: MessagePriority = .normal) -> UUID {
        let message = GenerationMessage(note: note, priority: priority)
        enqueue(message)
        metrics.totalPublished += 1
        Task { await drainQueue() }
        return message.id
    }

    /// Cancel a pending message before it is processed.
    func cancel(messageID: UUID) {
        mainQueue.removeAll { $0.id == messageID }
        metrics.pending = mainQueue.count
    }

    /// Remove all pending messages from the main queue (purge).
    func purge() {
        mainQueue.removeAll()
        metrics.pending = 0
    }

    // MARK: - Consumer API

    /// Subscribe to all generation results as an `AsyncStream`.
    ///
    /// Each call creates an independent consumer; all consumers receive every result
    /// (fanout / broadcast pattern). Unsubscribe by calling `unsubscribe(id:)` or
    /// by cancelling the owning `Task`.
    ///
    /// - Returns: A `(subscriberID, stream)` tuple. Keep the ID to unsubscribe.
    func subscribe() -> (id: UUID, stream: AsyncStream<GenerationResult>) {
        let id = UUID()
        var continuation: AsyncStream<GenerationResult>.Continuation!
        let stream = AsyncStream<GenerationResult> { cont in
            continuation = cont
        }
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.unsubscribe(id: id) }
        }
        return (id, stream)
    }

    /// Remove a consumer and finish its stream.
    func unsubscribe(id: UUID) {
        let continuation = subscribers.removeValue(forKey: id)
        continuation?.finish()
    }

    // MARK: - Dead-Letter Queue

    /// Re-publish all dead-lettered messages back to the main queue.
    func requeueDeadLetters() {
        let toRequeue = deadLetterQueue
        deadLetterQueue.removeAll()
        metrics.deadLettered = 0
        for var msg in toRequeue {
            msg.retryCount = 0
            enqueue(msg)
        }
        Task { await drainQueue() }
    }

    // MARK: - Private: Enqueue (priority-insert)

    private func enqueue(_ message: GenerationMessage) {
        // Binary-search-style insert: find first slot with strictly lower priority
        let insertAt = mainQueue.firstIndex { $0.priority < message.priority }
            ?? mainQueue.endIndex
        mainQueue.insert(message, at: insertAt)
        metrics.pending = mainQueue.count
    }

    // MARK: - Private: Worker Dispatch

    /// Dequeue and dispatch messages while workers are available.
    private func drainQueue() async {
        while activeWorkers < maxConcurrentWorkers, !mainQueue.isEmpty {
            let message = mainQueue.removeFirst()
            metrics.pending = mainQueue.count
            activeWorkers += 1
            metrics.processing = activeWorkers
            Task { await processMessage(message) }
        }
    }

    // MARK: - Private: Worker (one Task per message)

    private func processMessage(_ message: GenerationMessage) async {
        defer {
            Task {
                activeWorkers -= 1
                metrics.processing = activeWorkers
                await drainQueue()
            }
        }

        do {
            let cards = try await generationService.generateFlashcards(
                from: message.note.transcript,
                noteID: message.note.id
            )
            let deck = FlashcardDeck(sourceNote: message.note, cards: cards)
            metrics.completed += 1
            broadcast(GenerationResult(
                messageID: message.id,
                noteID:    message.note.id,
                outcome:   .success(deck)
            ))

        } catch {
            // NACK: retry with backoff, or dead-letter after max attempts
            var failed = message
            failed.retryCount += 1

            if failed.retryCount < maxDeliveryAttempts {
                let delay = retryBaseDelay * pow(2.0, Double(failed.retryCount - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                enqueue(failed)
                await drainQueue()
            } else {
                deadLetterQueue.append(failed)
                metrics.deadLettered = deadLetterQueue.count
                broadcast(GenerationResult(
                    messageID: message.id,
                    noteID:    message.note.id,
                    outcome:   .deadLetter(error)
                ))
            }
        }
    }

    // MARK: - Private: Fanout Broadcast

    private func broadcast(_ result: GenerationResult) {
        for continuation in subscribers.values {
            continuation.yield(result)
        }
    }
}
