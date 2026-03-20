import XCTest
@testable import VoicenoteAnki

/// Tests for APIKeyService.
///
/// These tests exercise the service's public API using a shared singleton instance.
/// Each test saves and restores state to avoid contaminating subsequent tests or
/// any real keychain data that may already exist.
final class APIKeyServiceTests: XCTestCase {

    private let service = APIKeyService.shared

    /// Snapshot of keys before the test; restored in tearDown.
    private var originalKeys: [String] = []

    override func setUp() {
        super.setUp()
        originalKeys = service.apiKeys
        // Start each test with a clean slate
        service.setKeys([])
    }

    override func tearDown() {
        // Restore original state
        service.setKeys(originalKeys)
        super.tearDown()
    }

    // MARK: - Initial state

    func testHasKeyReturnsFalseWhenNoKeys() {
        XCTAssertFalse(service.hasKey)
    }

    func testAPIKeysReturnsEmptyWhenNoKeys() {
        XCTAssertTrue(service.apiKeys.isEmpty)
    }

    func testAPIKeyReturnsNilWhenNoKeys() {
        XCTAssertNil(service.apiKey)
    }

    // MARK: - setKeys

    func testSetKeysSingleKey() {
        service.setKeys(["sk-test-key1"])
        XCTAssertEqual(service.apiKeys, ["sk-test-key1"])
    }

    func testSetKeysMultipleKeys() {
        service.setKeys(["sk-key1", "sk-key2", "sk-key3"])
        XCTAssertEqual(service.apiKeys.count, 3)
        XCTAssertTrue(service.apiKeys.contains("sk-key1"))
        XCTAssertTrue(service.apiKeys.contains("sk-key2"))
        XCTAssertTrue(service.apiKeys.contains("sk-key3"))
    }

    func testSetKeysTrimsWhitespace() {
        service.setKeys(["  sk-key1  ", "  sk-key2  "])
        XCTAssertTrue(service.apiKeys.contains("sk-key1"))
        XCTAssertTrue(service.apiKeys.contains("sk-key2"))
        XCTAssertFalse(service.apiKeys.contains("  sk-key1  "))
    }

    func testSetKeysFiltersEmptyStrings() {
        service.setKeys(["", "sk-valid", "  "])
        XCTAssertEqual(service.apiKeys, ["sk-valid"])
    }

    func testSetKeysEmptyArrayClearsAll() {
        service.setKeys(["sk-key1", "sk-key2"])
        service.setKeys([])
        XCTAssertTrue(service.apiKeys.isEmpty)
    }

    func testSetKeysReplacesExistingKeys() {
        service.setKeys(["sk-old1", "sk-old2"])
        service.setKeys(["sk-new1"])
        XCTAssertEqual(service.apiKeys, ["sk-new1"])
    }

    // MARK: - addKey

    func testAddKeyIncreasesCount() {
        service.addKey("sk-key1")
        XCTAssertEqual(service.apiKeys.count, 1)
    }

    func testAddKeyStoresKey() {
        service.addKey("sk-key-abc")
        XCTAssertTrue(service.apiKeys.contains("sk-key-abc"))
    }

    func testAddDuplicateKeyDoesNotIncreaseCount() {
        service.addKey("sk-key1")
        service.addKey("sk-key1")
        XCTAssertEqual(service.apiKeys.count, 1)
    }

    func testAddEmptyKeyDoesNotIncreaseCount() {
        service.addKey("")
        service.addKey("   ")
        XCTAssertTrue(service.apiKeys.isEmpty)
    }

    func testAddMultipleDistinctKeys() {
        service.addKey("sk-key1")
        service.addKey("sk-key2")
        service.addKey("sk-key3")
        XCTAssertEqual(service.apiKeys.count, 3)
    }

    func testAddKeyTrimsWhitespace() {
        service.addKey("  sk-trimmed  ")
        XCTAssertTrue(service.apiKeys.contains("sk-trimmed"))
        XCTAssertFalse(service.apiKeys.contains("  sk-trimmed  "))
    }

    // MARK: - removeKey

    func testRemoveKeyDecreasesCount() {
        service.setKeys(["sk-key1", "sk-key2"])
        service.removeKey("sk-key1")
        XCTAssertEqual(service.apiKeys.count, 1)
    }

    func testRemoveKeyRemovesCorrectKey() {
        service.setKeys(["sk-key1", "sk-key2"])
        service.removeKey("sk-key1")
        XCTAssertFalse(service.apiKeys.contains("sk-key1"))
        XCTAssertTrue(service.apiKeys.contains("sk-key2"))
    }

    func testRemoveNonExistentKeyDoesNotChangeCount() {
        service.setKeys(["sk-key1"])
        service.removeKey("sk-nonexistent")
        XCTAssertEqual(service.apiKeys.count, 1)
    }

    func testRemoveAllKeysLeavesEmpty() {
        service.setKeys(["sk-key1", "sk-key2"])
        service.removeKey("sk-key1")
        service.removeKey("sk-key2")
        XCTAssertTrue(service.apiKeys.isEmpty)
    }

    // MARK: - apiKey (single-key convenience)

    func testAPIKeyReturnsFirstKey() {
        service.setKeys(["sk-first", "sk-second"])
        XCTAssertEqual(service.apiKey, "sk-first")
    }

    func testSettingAPIKeyReplacesPool() {
        service.setKeys(["sk-old1", "sk-old2"])
        service.apiKey = "sk-new"
        XCTAssertEqual(service.apiKeys, ["sk-new"])
    }

    func testSettingAPIKeyToNilClearsPool() {
        service.setKeys(["sk-key1"])
        service.apiKey = nil
        XCTAssertTrue(service.apiKeys.isEmpty)
    }

    func testSettingAPIKeyToEmptyClearsPool() {
        service.setKeys(["sk-key1"])
        service.apiKey = ""
        XCTAssertTrue(service.apiKeys.isEmpty)
    }

    // MARK: - hasKey

    func testHasKeyReturnsTrueWhenKeyPresent() {
        service.setKeys(["sk-key1"])
        XCTAssertTrue(service.hasKey)
    }

    func testHasKeyReturnsFalseAfterRemovingAllKeys() {
        service.setKeys(["sk-key1"])
        service.removeKey("sk-key1")
        XCTAssertFalse(service.hasKey)
    }

    // MARK: - Persistence (round-trip)

    func testKeysPersistAcrossReads() {
        service.setKeys(["sk-persist-test"])
        // Read immediately (same service instance, re-queries keychain each time)
        XCTAssertEqual(service.apiKeys, ["sk-persist-test"])
    }

    func testMultipleKeysPersistAcrossReads() {
        let keys = ["sk-key-a", "sk-key-b", "sk-key-c"]
        service.setKeys(keys)
        let loaded = service.apiKeys
        XCTAssertEqual(loaded.count, 3)
        for key in keys {
            XCTAssertTrue(loaded.contains(key), "Missing key: \(key)")
        }
    }
}
