import XCTest
import CoreData
@testable import PusherPlatform

class NSPersistentStoreDescription_RecoveryTests: XCTestCase {
    
    // MARK: - Properties
    
    var url: URL!
    var moveURL: URL!
    
    // MARK: - Tests lifecycle
    
    override func setUp() {
        super.setUp()
        
        self.url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.sqlite")
        self.moveURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("movedTest.sqlite")
        
        FileManager.default.createFile(atPath: self.url.path, contents: nil, attributes: nil)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: self.url)
        try? FileManager.default.removeItem(at: self.moveURL)
    }
    
    // MARK: - Tests
    
    func testShouldNotAttemptToRecoverForFailPolicy() {
        let storeDescription =  NSPersistentStoreDescription(sqlitePersistentStoreDescriptionWithURL: self.url, errorRecoveryPolicy: .fail)
        storeDescription.attemptRecovery()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.url.path))
    }
    
    func testShouldRecoverForDeleteStorePolicy() {
        let storeDescription =  NSPersistentStoreDescription(sqlitePersistentStoreDescriptionWithURL: self.url, errorRecoveryPolicy: .deleteStore)
        storeDescription.attemptRecovery()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.url.path))
    }
    
    func testShouldRecoverForBackupStorePolicy() {
        let storeDescription =  NSPersistentStoreDescription(sqlitePersistentStoreDescriptionWithURL: self.url, errorRecoveryPolicy: .backupStore(self.moveURL))
        storeDescription.attemptRecovery()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: self.moveURL.path))
    }
    
}
