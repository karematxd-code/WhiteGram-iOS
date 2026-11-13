import XCTest
@testable import WhiteGramCore

final class WhiteGramCoreTests: XCTestCase {
    
    func testVersionInfo() {
        XCTAssertEqual(WhiteGramVersion.string, "0.5.3-beta")
        XCTAssertEqual(WhiteGramVersion.buildNumber, 530)
        XCTAssertEqual(WhiteGramVersion.bundleId, "org.whitegram.messenger")
        XCTAssertTrue(WhiteGramVersion.fullDescription.contains("WhiteGram iOS"))
    }
    
    func testStorageBasics() {
        let storage = WhiteGramStorage.shared
        storage.set("test_value", forKey: "unit_test_key")
        let retrieved: String? = storage.get(forKey: "unit_test_key")
        XCTAssertEqual(retrieved, "test_value")
        
        storage.set(true, forKey: "unit_test_bool")
        XCTAssertTrue(storage.bool(forKey: "unit_test_bool"))
    }
    
    func testLoggingDoesNotCrash() {
        WhiteGramLog.debug("Test debug log")
        WhiteGramLog.info("Test info log")
        WhiteGramLog.warning("Test warning log")
        WhiteGramLog.error("Test error log")
    }
}
