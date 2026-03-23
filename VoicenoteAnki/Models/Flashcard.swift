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

// MARK: - CardAttachment

enum AttachmentType: String, Codable {
    case image
    case pdf
    case audio
    case other
}

struct CardAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var type: AttachmentType
    /// Relative path from Documents directory (for portability)
    var relativePath: String

    init(id: UUID = UUID(), fileName: String, type: AttachmentType, relativePath: String) {
        self.id = id
        self.fileName = fileName
        self.type = type
        self.relativePath = relativePath
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

    // Attachments
    var attachments: [CardAttachment] = []

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
        sourceNoteID: UUID,
        attachments: [CardAttachment] = []
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.tags = tags
        self.difficulty = difficulty
        self.sourceNoteID = sourceNoteID
        self.attachments = attachments
    }
}

// MARK: - Folder

struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String   // e.g. "4A90D9" for tinting the folder icon
    let createdAt: Date

    init(id: UUID = UUID(), name: String, colorHex: String = "5E7CE2", createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

// MARK: - FlashcardDeck

struct FlashcardDeck: Identifiable, Codable {
    let id: UUID
    let sourceNote: VoiceNote
    var cards: [Flashcard]
    let createdAt: Date
    /// The folder this deck belongs to, or nil for the root level.
    var folderID: UUID?

    init(id: UUID = UUID(), sourceNote: VoiceNote, cards: [Flashcard], createdAt: Date = .now, folderID: UUID? = nil) {
        self.id = id
        self.sourceNote = sourceNote
        self.cards = cards
        self.createdAt = createdAt
        self.folderID = folderID
    }

    var title: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Note — \(formatter.string(from: sourceNote.date))"
    }
}
