import Foundation

/// Persists flashcard decks and folders to the app's Documents directory as JSON.
final class PersistenceService {

    static let shared = PersistenceService()

    private let decksFileName = "decks.json"
    private let foldersFileName = "folders.json"
    private let directoryURL: URL

    private var decksFileURL: URL {
        directoryURL.appendingPathComponent(decksFileName)
    }

    private var foldersFileURL: URL {
        directoryURL.appendingPathComponent(foldersFileName)
    }

    // MARK: - Init

    init(directoryURL: URL? = nil) {
        self.directoryURL = directoryURL
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Decks

    func save(_ decks: [FlashcardDeck]) throws {
        let data = try JSONEncoder().encode(decks)
        try data.write(to: decksFileURL, options: .atomic)
    }

    func load() throws -> [FlashcardDeck] {
        guard FileManager.default.fileExists(atPath: decksFileURL.path) else { return [] }
        let data = try Data(contentsOf: decksFileURL)
        return try JSONDecoder().decode([FlashcardDeck].self, from: data)
    }

    // MARK: - Folders

    func saveFolders(_ folders: [Folder]) throws {
        let data = try JSONEncoder().encode(folders)
        try data.write(to: foldersFileURL, options: .atomic)
    }

    func loadFolders() throws -> [Folder] {
        guard FileManager.default.fileExists(atPath: foldersFileURL.path) else { return [] }
        let data = try Data(contentsOf: foldersFileURL)
        return try JSONDecoder().decode([Folder].self, from: data)
    }
}
