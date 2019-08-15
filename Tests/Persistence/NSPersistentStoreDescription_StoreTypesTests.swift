import XCTest
import CoreData
@testable import PusherPlatform

class NSPersistentStoreDescription_StoreTypesTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldInitializeInMemoryStoreDescriptionWithDefaultValues() {
        let storeDescription = NSPersistentStoreDescription(inMemoryPersistentStoreDescription: ())
        
        XCTAssertEqual(storeDescription.type, NSInMemoryStoreType)
        XCTAssertEqual(storeDescription.url, URL(string: "file:///dev/null"))
        XCTAssertNil(storeDescription.configuration)
        XCTAssertTrue(storeDescription.shouldAddStoreAsynchronously)
        XCTAssertTrue(storeDescription.shouldInferMappingModelAutomatically)
    }
    
    func testShouldInitializeInMemoryStoreDescriptionWithDefaultValuesForEmptyConfiguration() {
        let storeDescription = NSPersistentStoreDescription(inMemoryPersistentStoreDescriptionForConfiguration: nil)
        
        XCTAssertEqual(storeDescription.type, NSInMemoryStoreType)
        XCTAssertEqual(storeDescription.url, URL(string: "file:///dev/null"))
        XCTAssertNil(storeDescription.configuration)
        XCTAssertTrue(storeDescription.shouldAddStoreAsynchronously)
        XCTAssertTrue(storeDescription.shouldInferMappingModelAutomatically)
    }
    
    func testShouldInitializeInMemoryStoreDescriptionWithCustomValues() {
        let storeDescription = NSPersistentStoreDescription(inMemoryPersistentStoreDescriptionForConfiguration: "testConfiguration",
                                                            shouldAddStoreAsynchronously: false,
                                                            shouldInferMappingModelAutomatically: false)
        
        XCTAssertEqual(storeDescription.type, NSInMemoryStoreType)
        XCTAssertEqual(storeDescription.url, URL(string: "file:///dev/null"))
        XCTAssertEqual(storeDescription.configuration, "testConfiguration")
        XCTAssertFalse(storeDescription.shouldAddStoreAsynchronously)
        XCTAssertFalse(storeDescription.shouldInferMappingModelAutomatically)
    }
    
    func testShouldInitializeSQLiteStoreDescriptionWithDefaultValues() {
        let testURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        let storeDescription = NSPersistentStoreDescription(sqlitePersistentStoreDescriptionWithURL: testURL, errorRecoveryPolicy: .deleteStore)
        
        XCTAssertEqual(storeDescription.type, NSSQLiteStoreType)
        XCTAssertEqual(storeDescription.url, testURL)
        XCTAssertEqual(storeDescription.errorRecoveryPolicy, ErrorRecoveryPolicy.deleteStore)
        XCTAssertNil(storeDescription.configuration)
        XCTAssertFalse(storeDescription.isReadOnly)
        XCTAssertTrue(storeDescription.shouldAddStoreAsynchronously)
        XCTAssertTrue(storeDescription.shouldMigrateStoreAutomatically)
        XCTAssertTrue(storeDescription.shouldInferMappingModelAutomatically)
        XCTAssertEqual(storeDescription.sqlitePragmas["journal_mode"] as? String, SQLiteJournalMode.writeAheadLog.rawValue)
    }
    
    func testShouldInitializeSQLiteStoreDescriptionWithCustomValues() {
        let testURL = URL(fileURLWithPath: NSTemporaryDirectory())
        
        let storeDescription = NSPersistentStoreDescription(sqlitePersistentStoreDescriptionWithURL: testURL,
                                                            errorRecoveryPolicy: .deleteStore,
                                                            configuration: "testConfiguration",
                                                            isReadOnly: true,
                                                            journalMode: .off,
                                                            shouldAddStoreAsynchronously: false,
                                                            shouldMigrateStoreAutomatically: false,
                                                            shouldInferMappingModelAutomatically: false)
        
        XCTAssertEqual(storeDescription.type, NSSQLiteStoreType)
        XCTAssertEqual(storeDescription.url, testURL)
        XCTAssertEqual(storeDescription.errorRecoveryPolicy, ErrorRecoveryPolicy.deleteStore)
        XCTAssertEqual(storeDescription.configuration, "testConfiguration")
        XCTAssertTrue(storeDescription.isReadOnly)
        XCTAssertFalse(storeDescription.shouldAddStoreAsynchronously)
        XCTAssertFalse(storeDescription.shouldMigrateStoreAutomatically)
        XCTAssertFalse(storeDescription.shouldInferMappingModelAutomatically)
        XCTAssertEqual(storeDescription.sqlitePragmas["journal_mode"] as? String, SQLiteJournalMode.off.rawValue)
    }
    
}
