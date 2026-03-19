import Foundation

// MARK: - Difficulty

enum Difficulty: String, CaseIterable, Codable {
    case easy   = "easy"
    case medium = "medium"
    case hard   = "hard"

    var label: String { rawValue.capitalized }

    var color: String {
        switch self {
        case .easy:   return "green"
        case .medium: return "orange"
        case .hard:   return "red"
        }
    }
}

// MARK: - Flashcard

struct Flashcard: Identifiable, Codable, Equatable {
    let id: UUID
    var front: String          // question / term
    var back: String           // answer / definition
    var tags: [String]
    var difficulty: Difficulty
    let sourceNoteID: UUID

    // Study state (not persisted in this version)
    var isStarred: Bool = false
    var reviewCount: Int = 0
    var lastReviewedAt: Date?

    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        tags: [String] = [],
        difficulty: Difficulty = .medium,
        sourceNoteID: UUID
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.tags = tags
        self.difficulty = difficulty
        self.sourceNoteID = sourceNoteID
    }
}

// MARK: - FlashcardDeck

struct FlashcardDeck: Identifiable, Codable {
    let id: UUID
    let sourceNote: VoiceNote
    var cards: [Flashcard]
    let createdAt: Date

    init(id: UUID = UUID(), sourceNote: VoiceNote, cards: [Flashcard], createdAt: Date = .now) {
        self.id = id
        self.sourceNote = sourceNote
        self.cards = cards
        self.createdAt = createdAt
    }

    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Note — \(formatter.string(from: sourceNote.date))"
    }
}
