import XCTest
@testable import VoicenoteAnki

final class LoadBalancerServiceTests: XCTestCase {

    // MARK: - Initialization

    func testInitWithNoKeysHasZeroKeyCount() async {
        let lb = LoadBalancerService(keys: [])
        let count = await lb.keyCount
        XCTAssertEqual(count, 0)
    }

    func testInitFiltersEmptyKeys() async {
        let lb = LoadBalancerService(keys: ["", "  ", "valid-key"])
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    func testInitWithMultipleKeys() async {
        let lb = LoadBalancerService(keys: ["key1", "key2", "key3"])
        let count = await lb.keyCount
        XCTAssertEqual(count, 3)
    }

    // MARK: - noKeysConfigured error

    func testAcquireKeyWithNoKeysThrowsNoKeysConfigured() async {
        let lb = LoadBalancerService(keys: [])
        do {
            _ = try await lb.acquireKey()
            XCTFail("Expected LoadBalancerError.noKeysConfigured")
        } catch LoadBalancerError.noKeysConfigured {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - addKey

    func testAddKeyIncreasesCount() async {
        let lb = LoadBalancerService(keys: [])
        await lb.addKey("new-key")
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    func testAddDuplicateKeyDoesNotIncreaseCount() async {
        let lb = LoadBalancerService(keys: ["key1"])
        await lb.addKey("key1")
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    func testAddEmptyKeyDoesNotIncreaseCount() async {
        let lb = LoadBalancerService(keys: [])
        await lb.addKey("")
        await lb.addKey("   ")
        let count = await lb.keyCount
        XCTAssertEqual(count, 0)
    }

    func testAddKeyTrimsWhitespace() async {
        let lb = LoadBalancerService(keys: [])
        await lb.addKey("  key1  ")
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
        // The trimmed version is stored, so acquiring should work
        let key = try? await lb.acquireKey()
        XCTAssertEqual(key, "key1")
    }

    // MARK: - removeKey

    func testRemoveKeyDecreasesCount() async {
        let lb = LoadBalancerService(keys: ["key1", "key2"])
        await lb.removeKey("key1")
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    func testRemoveNonExistentKeyDoesNotChangeCount() async {
        let lb = LoadBalancerService(keys: ["key1"])
        await lb.removeKey("nonexistent")
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    func testRemoveAllKeysLeavesEmptyPool() async {
        let lb = LoadBalancerService(keys: ["key1", "key2"])
        await lb.removeKey("key1")
        await lb.removeKey("key2")
        let count = await lb.keyCount
        XCTAssertEqual(count, 0)
    }

    // MARK: - setKeys

    func testSetKeysReplacesPool() async {
        let lb = LoadBalancerService(keys: ["old1", "old2"])
        await lb.setKeys(["new1"])
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
        let key = try? await lb.acquireKey()
        XCTAssertEqual(key, "new1")
    }

    func testSetEmptyKeysEmptiesPool() async {
        let lb = LoadBalancerService(keys: ["key1", "key2"])
        await lb.setKeys([])
        let count = await lb.keyCount
        XCTAssertEqual(count, 0)
    }

    func testSetKeysFiltersEmptyStrings() async {
        let lb = LoadBalancerService(keys: [])
        await lb.setKeys(["", "valid", ""])
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    // MARK: - availableKeyCount

    func testAllKeysAvailableByDefault() async {
        let lb = LoadBalancerService(keys: ["key1", "key2", "key3"])
        let available = await lb.availableKeyCount
        XCTAssertEqual(available, 3)
    }

    func testAvailableKeyCountDecreasesAfterRateLimit() async {
        let lb = LoadBalancerService(keys: ["key1", "key2"])
        // Acquire and release with rate-limit
        let key = try? await lb.acquireKey()
        XCTAssertNotNil(key)
        await lb.releaseKey(key!, rateLimited: true)
        let available = await lb.availableKeyCount
        // One key is rate-limited
        XCTAssertEqual(available, 1)
    }

    // MARK: - Round-robin strategy

    func testRoundRobinRotatesThroughKeys() async {
        let lb = LoadBalancerService(keys: ["key1", "key2", "key3"], strategy: .roundRobin)
        let k1 = try? await lb.acquireKey()
        let k2 = try? await lb.acquireKey()
        let k3 = try? await lb.acquireKey()
        let k4 = try? await lb.acquireKey()
        XCTAssertEqual(k1, "key1")
        XCTAssertEqual(k2, "key2")
        XCTAssertEqual(k3, "key3")
        XCTAssertEqual(k4, "key1") // wraps around
    }

    func testRoundRobinSkipsRateLimitedKey() async {
        let lb = LoadBalancerService(keys: ["key1", "key2"], strategy: .roundRobin)
        // Rate-limit key1
        let k1 = try? await lb.acquireKey()
        XCTAssertEqual(k1, "key1")
        await lb.releaseKey("key1", rateLimited: true)
        // Next acquire should skip key1 and use key2
        let k2 = try? await lb.acquireKey()
        XCTAssertEqual(k2, "key2")
    }

    func testRoundRobinThrowsWhenAllRateLimited() async {
        let lb = LoadBalancerService(keys: ["key1"], strategy: .roundRobin)
        let k1 = try? await lb.acquireKey()
        await lb.releaseKey(k1!, rateLimited: true)
        do {
            _ = try await lb.acquireKey()
            XCTFail("Expected LoadBalancerError.noAvailableKeys")
        } catch LoadBalancerError.noAvailableKeys {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Least-connections strategy

    func testLeastConnectionsPrefersKeyWithFewerConnections() async {
        let lb = LoadBalancerService(keys: ["key1", "key2"], strategy: .leastConnections)
        // Acquire key1 twice to increase its connection count
        _ = try? await lb.acquireKey()  // key1 (0 conns initially, becomes 1)
        // key2 still has 0, so next should be key2
        let next = try? await lb.acquireKey()
        XCTAssertEqual(next, "key2")
    }

    func testLeastConnectionsThrowsWhenAllRateLimited() async {
        let lb = LoadBalancerService(keys: ["key1"], strategy: .leastConnections)
        let k = try? await lb.acquireKey()
        await lb.releaseKey(k!, rateLimited: true)
        do {
            _ = try await lb.acquireKey()
            XCTFail("Expected LoadBalancerError.noAvailableKeys")
        } catch LoadBalancerError.noAvailableKeys {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Random strategy

    func testRandomStrategyReturnsAKey() async {
        let lb = LoadBalancerService(keys: ["key1", "key2", "key3"], strategy: .random)
        let key = try? await lb.acquireKey()
        XCTAssertNotNil(key)
        let validKeys = ["key1", "key2", "key3"]
        XCTAssertTrue(validKeys.contains(key!))
    }

    func testRandomStrategyThrowsWhenAllRateLimited() async {
        let lb = LoadBalancerService(keys: ["key1"], strategy: .random)
        let k = try? await lb.acquireKey()
        await lb.releaseKey(k!, rateLimited: true)
        do {
            _ = try await lb.acquireKey()
            XCTFail("Expected LoadBalancerError.noAvailableKeys")
        } catch LoadBalancerError.noAvailableKeys {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - releaseKey

    func testReleaseWithoutRateLimitDoesNotMarkKeyAsLimited() async {
        let lb = LoadBalancerService(keys: ["key1"], strategy: .roundRobin)
        let key = try? await lb.acquireKey()
        await lb.releaseKey(key!, rateLimited: false)
        // Key should still be available
        let available = await lb.availableKeyCount
        XCTAssertEqual(available, 1)
    }

    func testReleaseNonExistentKeyDoesNotCrash() async {
        let lb = LoadBalancerService(keys: ["key1"])
        // Should not throw or crash
        await lb.releaseKey("nonexistent-key", rateLimited: false)
        let count = await lb.keyCount
        XCTAssertEqual(count, 1)
    }

    func testConnectionCountDecrementsOnRelease() async {
        // After release without rate-limit, the key should be acquirable again
        let lb = LoadBalancerService(keys: ["key1"], strategy: .leastConnections)
        let k1 = try? await lb.acquireKey()
        await lb.releaseKey(k1!, rateLimited: false)
        // Should be able to acquire again
        let k2 = try? await lb.acquireKey()
        XCTAssertEqual(k2, "key1")
    }

    // MARK: - Error descriptions

    func testNoKeysConfiguredErrorHasDescription() {
        let error = LoadBalancerError.noKeysConfigured
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testNoAvailableKeysErrorHasDescription() {
        let error = LoadBalancerError.noAvailableKeys
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testNoKeysConfiguredErrorContainsKeyword() {
        let error = LoadBalancerError.noKeysConfigured
        XCTAssertTrue(error.errorDescription!.lowercased().contains("key") ||
                      error.errorDescription!.lowercased().contains("configured"))
    }

    func testNoAvailableKeysErrorContainsKeyword() {
        let error = LoadBalancerError.noAvailableKeys
        XCTAssertTrue(error.errorDescription!.lowercased().contains("rate") ||
                      error.errorDescription!.lowercased().contains("available"))
    }
}
