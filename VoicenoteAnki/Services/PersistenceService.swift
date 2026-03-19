import Foundation

/// Persists flashcard decks to the app's Documents directory as JSON.
final class PersistenceService {

    static let shared = PersistenceService()

    private let fileName = "decks.json"
    private let directoryURL: URL

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    // MARK: - Init

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Public API

    func save(_ decks: [FlashcardDeck]) throws {
        let data = try JSONEncoder().encode(decks)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> [FlashcardDeck] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([FlashcardDeck].self, from: data)
    }
}
