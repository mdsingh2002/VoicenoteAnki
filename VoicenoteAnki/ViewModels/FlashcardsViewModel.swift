import SwiftUI
import Combine

@MainActor
final class FlashcardsViewModel: ObservableObject {

    // MARK: - Published state
    @Published private(set) var decks: [FlashcardDeck] = []
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var isGenerating = false
    @Published var errorMessage: String?

    /// Deck waiting for user review before being committed to `decks`.
    @Published private(set) var pendingDeck: FlashcardDeck?

    // Active study session
    @Published var activeDeck: FlashcardDeck?
    @Published private(set) var currentCardIndex: Int = 0
    @Published private(set) var isShowingBack = false
    @Published private(set) var sessionComplete = false

    // MARK: - Queue metrics (exposed for UI)

    /// Total messages currently pending or in-flight.
    @Published private(set) var queueDepth: Int = 0
    /// Messages that exhausted all retry attempts.
    @Published private(set) var deadLetterCount: Int = 0

    // MARK: - Private
    private let queue = GenerationQueueService.shared
    private let persistence: PersistenceService
    private var subscriberID: UUID?
    private var consumerTask: Task<Void, Never>?

    // MARK: - Init

    init(persistence: PersistenceService = .shared) {
        self.persistence = persistence
        if let saved = try? persistence.load() {
            _decks = Published(initialValue: saved)
        }
        if let savedFolders = try? persistence.loadFolders() {
            _folders = Published(initialValue: savedFolders)
        }
        startConsuming()
    }

    deinit {
        consumerTask?.cancel()
    }

    // MARK: - Queue Consumer

    /// Subscribe to the shared GenerationQueueService and process incoming results.
    private func startConsuming() {
        consumerTask = Task { [weak self] in
            guard let self else { return }

            let (id, stream) = await queue.subscribe()
            subscriberID = id

            for await result in stream {
                guard !Task.isCancelled else { break }
                handleResult(result)
                let m = await queue.metrics
                queueDepth      = m.pending + m.processing
                deadLetterCount = m.deadLettered
                isGenerating    = queueDepth > 0
            }
        }
    }

    private func handleResult(_ result: GenerationResult) {
        switch result.outcome {
        case .success(let deck):
            pendingDeck  = deck
            errorMessage = nil
        case .deadLetter(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Generation

    func generateDeck(for note: VoiceNote, priority: MessagePriority = .normal) async {
        guard !note.transcript.isEmpty else {
            errorMessage = "No transcript yet — finish recording first."
            return
        }
        errorMessage = nil
        await queue.publish(note: note, priority: priority)

        let m = await queue.metrics
        queueDepth   = m.pending + m.processing
        isGenerating = queueDepth > 0
    }

    // MARK: - Pending deck management

    /// User approved the preview — move the pending deck into the saved list.
    func confirmPendingDeck(_ deck: FlashcardDeck) {
        decks.insert(deck, at: 0)
        pendingDeck = nil
        try? persistence.save(decks)
    }

    func discardPendingDeck() {
        pendingDeck = nil
    }

    func updatePendingCard(_ card: Flashcard) {
        guard var deck = pendingDeck,
              let idx = deck.cards.firstIndex(where: { $0.id == card.id }) else { return }
        deck.cards[idx] = card
        pendingDeck = deck
    }

    func deletePendingCard(at offsets: IndexSet) {
        guard var deck = pendingDeck else { return }
        deck.cards.remove(atOffsets: offsets)
        pendingDeck = deck
    }

    // MARK: - Dead-letter queue management

    func retryDeadLetters() async {
        await queue.requeueDeadLetters()
        let m = await queue.metrics
        deadLetterCount = m.deadLettered
        queueDepth      = m.pending + m.processing
        isGenerating    = queueDepth > 0
    }

    // MARK: - Folder management

    /// Create a new folder with the given name.
    @discardableResult
    func createFolder(name: String, colorHex: String = "5E7CE2") -> Folder {
        let folder = Folder(name: name, colorHex: colorHex)
        folders.append(folder)
        try? persistence.saveFolders(folders)
        return folder
    }

    func renameFolder(id: UUID, to newName: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = newName
        try? persistence.saveFolders(folders)
    }

    func updateFolderColor(id: UUID, colorHex: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].colorHex = colorHex
        try? persistence.saveFolders(folders)
    }

    /// Delete a folder. Decks inside are moved to the root (folderID = nil).
    func deleteFolder(id: UUID) {
        folders.removeAll { $0.id == id }
        for i in decks.indices where decks[i].folderID == id {
            decks[i].folderID = nil
        }
        try? persistence.saveFolders(folders)
        try? persistence.save(decks)
    }

    /// Move a deck to a folder (pass nil to move to root).
    func moveDeck(id: UUID, toFolder folderID: UUID?) {
        guard let idx = decks.firstIndex(where: { $0.id == id }) else { return }
        decks[idx].folderID = folderID
        try? persistence.save(decks)
    }

    /// Decks that belong to the given folder (nil = root / unfiled).
    func decks(in folderID: UUID?) -> [FlashcardDeck] {
        decks.filter { $0.folderID == folderID }
    }

    // MARK: - Study session

    func startStudySession(deck: FlashcardDeck) {
        activeDeck       = deck
        currentCardIndex = 0
        isShowingBack    = false
        sessionComplete  = false
    }

    func endStudySession() {
        activeDeck      = nil
        sessionComplete = false
    }

    func flipCard() {
        withAnimation(.spring(duration: 0.4)) {
            isShowingBack.toggle()
        }
    }

    func nextCard() {
        guard let deck = activeDeck else { return }
        isShowingBack = false
        if currentCardIndex < deck.cards.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentCardIndex += 1
            }
        } else {
            withAnimation(.spring(duration: 0.4)) {
                sessionComplete = true
            }
        }
    }

    func previousCard() {
        guard currentCardIndex > 0 else { return }
        isShowingBack = false
        withAnimation(.easeInOut(duration: 0.25)) {
            currentCardIndex -= 1
        }
    }

    func restartSession() {
        currentCardIndex = 0
        isShowingBack    = false
        sessionComplete  = false
    }

    // MARK: - Helpers

    var currentCard: Flashcard? {
        guard let deck = activeDeck, deck.cards.indices.contains(currentCardIndex) else { return nil }
        return deck.cards[currentCardIndex]
    }

    var progressFraction: Double {
        guard let deck = activeDeck, !deck.cards.isEmpty else { return 0 }
        return Double(currentCardIndex + 1) / Double(deck.cards.count)
    }

    func deleteDeck(at offsets: IndexSet, in folderID: UUID?) {
        let filtered = decks(in: folderID)
        let idsToDelete = offsets.map { filtered[$0].id }
        decks.removeAll { idsToDelete.contains($0.id) }
        try? persistence.save(decks)
    }

    func deleteDeck(at offsets: IndexSet) {
        decks.remove(atOffsets: offsets)
        try? persistence.save(decks)
    }

    // MARK: - Card editing on saved decks

    func updateCard(_ card: Flashcard, in deck: FlashcardDeck) {
        guard let deckIdx = decks.firstIndex(where: { $0.id == deck.id }),
              let cardIdx = decks[deckIdx].cards.firstIndex(where: { $0.id == card.id }) else { return }
        decks[deckIdx].cards[cardIdx] = card
        if activeDeck?.id == deck.id {
            activeDeck = decks[deckIdx]
        }
        try? persistence.save(decks)
    }
}
