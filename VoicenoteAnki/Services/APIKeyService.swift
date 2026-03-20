import Foundation
import Security

/// Stores one or more Anthropic API keys in the iOS Keychain and keeps the
/// shared `LoadBalancerService` in sync.
final class APIKeyService {

    static let shared = APIKeyService()
    private init() {}

    // MARK: - Keychain identifiers

    private let service = "VoicenoteAnki"
    /// Primary (first) key – backward-compatible account name.
    private let primaryAccount = "com.voicenote-anki.anthropic-api-key"
    /// Stores the full comma-separated list of keys.
    private let allKeysAccount  = "com.voicenote-anki.anthropic-api-keys"

    // MARK: - Single-key API (backward compatible)

    /// The primary API key. Setting this replaces the entire key pool with a
    /// single key. Use `addKey(_:)` / `removeKey(_:)` to manage a pool.
    var apiKey: String? {
        get { apiKeys.first }
        set {
            if let value = newValue, !value.isEmpty {
                setKeys([value])
            } else {
                setKeys([])
            }
        }
    }

    var hasKey: Bool { !apiKeys.isEmpty }

    // MARK: - Multi-key API

    /// All stored API keys.
    var apiKeys: [String] {
        get { loadKeys() }
    }

    /// Replace the entire key pool.
    func setKeys(_ keys: [String]) {
        let trimmed = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        saveKeys(trimmed)
        syncLoadBalancer(trimmed)
        // Keep legacy single-key property in sync for FlashcardGenerationService.apiKey
        FlashcardGenerationService.apiKey = trimmed.first ?? ""
    }

    /// Add a key to the pool (no-op if already present).
    func addKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var current = loadKeys()
        guard !current.contains(trimmed) else { return }
        current.append(trimmed)
        saveKeys(current)
        syncLoadBalancer(current)
        if current.count == 1 {
            FlashcardGenerationService.apiKey = trimmed
        }
    }

    /// Remove a key from the pool.
    func removeKey(_ key: String) {
        var current = loadKeys()
        current.removeAll { $0 == key }
        saveKeys(current)
        syncLoadBalancer(current)
        FlashcardGenerationService.apiKey = current.first ?? ""
    }

    // MARK: - Keychain helpers

    private func saveKeys(_ keys: [String]) {
        let joined = keys.joined(separator: ",")
        guard let data = joined.data(using: .utf8) else { return }

        // Save list under allKeysAccount
        deleteItem(account: allKeysAccount)
        if !keys.isEmpty {
            addItem(account: allKeysAccount, data: data)
        }

        // Keep the primary account in sync for backward compat
        deleteItem(account: primaryAccount)
        if let first = keys.first, let firstData = first.data(using: .utf8) {
            addItem(account: primaryAccount, data: firstData)
        }
    }

    private func loadKeys() -> [String] {
        // Prefer the multi-key store
        if let joined = loadItem(account: allKeysAccount), !joined.isEmpty {
            return joined.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        }
        // Fall back to legacy single-key store
        if let single = loadItem(account: primaryAccount), !single.isEmpty {
            return [single]
        }
        return []
    }

    private func addItem(account: String, data: Data) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadItem(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  account,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func deleteItem(account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Load balancer sync

    private func syncLoadBalancer(_ keys: [String]) {
        Task { await FlashcardGenerationService.loadBalancer.setKeys(keys) }
    }
}
