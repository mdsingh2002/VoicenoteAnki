import Foundation

// MARK: - Strategy

enum LoadBalancingStrategy {
    /// Rotate through keys in order.
    case roundRobin
    /// Pick the key with the fewest active requests.
    case leastConnections
    /// Pick a key at random.
    case random
}

// MARK: - Key health

private struct APIKeySlot {
    let key: String
    var activeConnections: Int = 0
    /// nil = healthy; non-nil = time after which the key may be retried.
    var rateLimitedUntil: Date? = nil

    var isAvailable: Bool {
        guard let until = rateLimitedUntil else { return true }
        return Date() >= until
    }
}

// MARK: - LoadBalancerService

/// Thread-safe client-side load balancer for Anthropic API keys.
///
/// Usage:
/// ```swift
/// let lb = LoadBalancerService(keys: ["sk-ant-...", "sk-ant-..."])
/// let key = try lb.acquireKey()
/// defer { lb.releaseKey(key, rateLimited: false) }
/// // ... make API request using key ...
/// ```
actor LoadBalancerService {

    // MARK: Configuration

    /// Cooldown after a 429 response before the key is retried (seconds).
    var rateLimitCooldown: TimeInterval = 60

    // MARK: State

    private var slots: [APIKeySlot]
    private var roundRobinIndex: Int = 0
    private let strategy: LoadBalancingStrategy

    // MARK: Init

    init(keys: [String], strategy: LoadBalancingStrategy = .roundRobin) {
        self.slots = keys.filter { !$0.isEmpty }.map { APIKeySlot(key: $0) }
        self.strategy = strategy
    }

    // MARK: Key management

    /// Add a new API key to the pool.
    func addKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !slots.contains(where: { $0.key == trimmed }) else { return }
        slots.append(APIKeySlot(key: trimmed))
    }

    /// Remove an API key from the pool.
    func removeKey(_ key: String) {
        slots.removeAll { $0.key == key }
    }

    /// Replace all keys with a new set.
    func setKeys(_ keys: [String]) {
        slots = keys.filter { !$0.isEmpty }.map { APIKeySlot(key: $0) }
        roundRobinIndex = 0
    }

    var keyCount: Int { slots.count }

    var availableKeyCount: Int { slots.filter { $0.isAvailable }.count }

    // MARK: Acquire / Release

    /// Return the next available API key according to the configured strategy.
    /// Throws `LoadBalancerError.noAvailableKeys` if all keys are rate-limited.
    func acquireKey() throws -> String {
        guard !slots.isEmpty else { throw LoadBalancerError.noKeysConfigured }

        switch strategy {
        case .roundRobin:    return try acquireRoundRobin()
        case .leastConnections: return try acquireLeastConnections()
        case .random:        return try acquireRandom()
        }
    }

    /// Call after a request completes to free up the connection counter.
    /// - Parameters:
    ///   - key: The key that was used.
    ///   - rateLimited: Pass `true` if the server returned HTTP 429.
    func releaseKey(_ key: String, rateLimited: Bool) {
        guard let idx = slots.firstIndex(where: { $0.key == key }) else { return }
        slots[idx].activeConnections = max(0, slots[idx].activeConnections - 1)
        if rateLimited {
            slots[idx].rateLimitedUntil = Date().addingTimeInterval(rateLimitCooldown)
        }
    }

    // MARK: - Private selection helpers

    private func acquireRoundRobin() throws -> String {
        let startIndex = roundRobinIndex
        var checked = 0
        while checked < slots.count {
            let idx = (startIndex + checked) % slots.count
            if slots[idx].isAvailable {
                slots[idx].activeConnections += 1
                roundRobinIndex = (idx + 1) % slots.count
                return slots[idx].key
            }
            checked += 1
        }
        throw LoadBalancerError.noAvailableKeys
    }

    private func acquireLeastConnections() throws -> String {
        guard let idx = slots.indices
            .filter({ slots[$0].isAvailable })
            .min(by: { slots[$0].activeConnections < slots[$1].activeConnections })
        else { throw LoadBalancerError.noAvailableKeys }

        slots[idx].activeConnections += 1
        return slots[idx].key
    }

    private func acquireRandom() throws -> String {
        let available = slots.indices.filter { slots[$0].isAvailable }
        guard !available.isEmpty else { throw LoadBalancerError.noAvailableKeys }
        let idx = available.randomElement()!
        slots[idx].activeConnections += 1
        return slots[idx].key
    }
}

// MARK: - Errors

enum LoadBalancerError: LocalizedError {
    case noKeysConfigured
    case noAvailableKeys

    var errorDescription: String? {
        switch self {
        case .noKeysConfigured:
            return "No API keys are configured in the load balancer."
        case .noAvailableKeys:
            return "All API keys are currently rate-limited. Please wait before retrying."
        }
    }
}
