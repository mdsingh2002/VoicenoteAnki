import Foundation
import Security

/// Stores the Anthropic API key in the iOS Keychain.
final class APIKeyService {

    static let shared = APIKeyService()
    private init() {}

    private let account = "com.voicenote-anki.anthropic-api-key"
    private let service = "VoicenoteAnki"

    // MARK: - Read

    var apiKey: String? {
        get { load() }
        set {
            if let value = newValue, !value.isEmpty {
                save(value)
            } else {
                delete()
            }
            // Keep the generation service in sync
            FlashcardGenerationService.apiKey = newValue ?? ""
        }
    }

    var hasKey: Bool { !(load() ?? "").isEmpty }

    // MARK: - Keychain helpers

    private func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete() // remove old entry first
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
