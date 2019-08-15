import XCTest
import CoreData
@testable import PusherPlatform

import XCTest

class PersistenceControllerTests: XCTestCase {
    
    // MARK: - Properties
    
    let testStoreDescription = NSPersistentStoreDescription(inMemoryPersistentStoreDescription: ())
    var testModel: NSManagedObjectModel!
    var persistenceController: PersistenceController!
    
    // MARK: - Tests lifecycle
    
    override func setUp() {
        super.setUp()
        
        guard let url = Bundle(for: type(of: self)).url(forResource: "TestModel", withExtension: "momd"), let model = NSManagedObjectModel(contentsOf: url) else {
            assertionFailure("Unable to locate test model.")
            return
        }
        
        self.testModel = model
        
        let instantiationExpectation = self.expectation(description: "Instantiation")
        
        do {
            self.persistenceController = try PersistenceController(model: self.testModel, storeDescriptions: [self.testStoreDescription], logger: PPDefaultLogger()) { error in
                if error != nil {
                    assertionFailure("Failed to create in-memory store.")
                }
                
                instantiationExpectation.fulfill()
            }
        } catch {
            assertionFailure("Failed to instantiat persistence controller.")
            instantiationExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Tests
    
    func testShouldNotInstantiatePersistenceControllerWithoutStoreDescriptions() {
        XCTAssertThrowsError(try PersistenceController(model: self.testModel, storeDescriptions: [])) { error in
            XCTAssertEqual(error as? PersistenceError, PersistenceError.persistentStoreDescriptionMissing)
        }
    }
    
    func testShouldHaveModelWithCorrectNumberOfEntities() {
        XCTAssertEqual(self.persistenceController.model, self.testModel)
        XCTAssertEqual(self.persistenceController.model.entities.count, 1)
    }
    
    func testShouldHaveMainContextWithCorrectSetup() {
        let privateContext = self.persistenceController.mainContext.parent
        
        XCTAssertNotNil(self.persistenceController.mainContext)
        XCTAssertEqual(self.persistenceController.mainContext.concurrencyType, NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        XCTAssertTrue(self.persistenceController.mainContext.automaticallyMergesChangesFromParent)
        XCTAssertNotNil(privateContext)
    }
    
    func testShouldHavePrivateContextWithCorrectSetup() {
        let privateContext = self.persistenceController.mainContext.parent
        
        XCTAssertNotNil(privateContext)
        XCTAssertNotNil(privateContext?.persistentStoreCoordinator)
        XCTAssertEqual(privateContext?.concurrencyType, NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        XCTAssertEqual(privateContext?.mergePolicy as? NSMergePolicy, NSMergeByPropertyObjectTrumpMergePolicy as? NSMergePolicy)
        XCTAssertNil(privateContext?.parent)
    }
    
    func testShouldHaveCorrectDefaultApplicationLifecycleSettings() {
        XCTAssertFalse(self.persistenceController.shouldSaveWhenApplicationWillResignActive)
        XCTAssertTrue(self.persistenceController.shouldSaveWhenApplicationDidEnterBackground)
        XCTAssertTrue(self.persistenceController.shouldSaveWhenApplicationWillTerminate)
    }
    
    func testShouldHaveAnInstanceOfLogger() {
        XCTAssertNotNil(self.persistenceController.logger)
    }
    
    func testPersistentStoreCoordinatorShouldHaveCorrectNumberOfStores() {
        XCTAssertEqual(self.persistenceController.storeCoordinator.persistentStores.count, 1)
        
        guard let persistentStore = self.persistenceController.storeCoordinator.persistentStores.first else {
            XCTFail("Persistent store coordinator should have exactly one store.")
            return
        }
        
        XCTAssertEqual(persistentStore.type, NSInMemoryStoreType)
    }
    
    func testCreateBackgroundContextWithCorrectSetup() {
        let privateContext = self.persistenceController.mainContext.parent
        
        let expectation = self.expectation(description: "Background task")
        
        self.persistenceController.performBackgroundTask { backgroundContext in
            XCTAssertEqual(backgroundContext.parent, privateContext)
            XCTAssertEqual(backgroundContext.concurrencyType, NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
            XCTAssertTrue(backgroundContext.automaticallyMergesChangesFromParent)
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldAutomaticallyPropagateChangesFromPrivateContextToMainContextWithoutSave() {
        let mainContext = self.persistenceController.mainContext
        
        guard let privateContext = mainContext.parent else {
            XCTFail("Persistence controller should have a private context.")
            return
        }
        
        privateContext.performAndWait {
            let testEntity = privateContext.create(TestEntity.self)
            testEntity.name = "privateContextTest"
            
            XCTAssertEqual(privateContext.count(TestEntity.self), 1)
            XCTAssertTrue(privateContext.hasChanges)
        }
        
        mainContext.performAndWait {
            XCTAssertFalse(mainContext.hasChanges)
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
            
            guard let result = mainContext.fetch(TestEntity.self) else {
                XCTFail("Main context should contain test entity.")
                return
            }
            
            XCTAssertEqual(result.name, "privateContextTest")
        }
    }
    
    func testShouldNotAutomaticallyPropagateChangesFromMainContextToPrivateContextWithoutSave() {
        let mainContext = self.persistenceController.mainContext
        
        guard let privateContext = mainContext.parent else {
            XCTFail("Persistence controller should have a private context.")
            return
        }
        
        mainContext.performAndWait {
            let _ = mainContext.create(TestEntity.self)
            
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
            XCTAssertTrue(mainContext.hasChanges)
        }
        
        privateContext.performAndWait {
            XCTAssertFalse(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 0)
        }
    }
    
    func testShouldPropagateChangesFromMainContextToPrivateContextAfterSave() {
        let mainContext = self.persistenceController.mainContext
        
        guard let privateContext = mainContext.parent else {
            XCTFail("Persistence controller should have a private context.")
            return
        }
        
        mainContext.performAndWait {
            let testEntity = mainContext.create(TestEntity.self)
            testEntity.name = "mainContextTest"
            
            XCTAssertTrue(mainContext.hasChanges)
            
            try? mainContext.save()
            
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
            XCTAssertFalse(mainContext.hasChanges)
        }
        
        privateContext.performAndWait {
            XCTAssertTrue(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 1)
            
            guard let result = privateContext.fetch(TestEntity.self) else {
                XCTFail("Private context should contain test entity.")
                return
            }
            
            XCTAssertEqual(result.name, "mainContextTest")
        }
    }
    
    func testShouldCorrectlyPropagateChangesFromBackgroundContextToOtherContexts() {
        let mainContext = self.persistenceController.mainContext
        
        guard let privateContext = mainContext.parent else {
            XCTFail("Persistence controller should have a private context.")
            return
        }
        
        let backgroundTaskExpectation = self.expectation(description: "Background task")
        
        self.persistenceController.performBackgroundTask { backgroundContext in
            XCTAssertFalse(backgroundContext.hasChanges)
            
            let testEntity = backgroundContext.create(TestEntity.self)
            testEntity.name = "backgroundContextTest"
            
            XCTAssertTrue(backgroundContext.hasChanges)
            
            try? backgroundContext.save()
            
            XCTAssertFalse(backgroundContext.hasChanges)
            
            backgroundTaskExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        privateContext.performAndWait {
            XCTAssertTrue(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 1)
            
            guard let result = privateContext.fetch(TestEntity.self) else {
                XCTFail("Private context should contain test entity.")
                return
            }
            
            XCTAssertEqual(result.name, "backgroundContextTest")
        }
        
        mainContext.performAndWait {
            XCTAssertFalse(mainContext.hasChanges)
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
            
            guard let result = mainContext.fetch(TestEntity.self) else {
                XCTFail("Main context should contain test entity.")
                return
            }
            
            XCTAssertEqual(result.name, "backgroundContextTest")
        }
    }
    
    func testShouldSaveWhenThereArePendingChangesInTheMainContext() {
        let mainContext = self.persistenceController.mainContext
        
        guard let privateContext = mainContext.parent else {
            XCTFail("Persistence controller should have a private context.")
            return
        }
        
        privateContext.performAndWait {
            XCTAssertFalse(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 0)
        }
        
        mainContext.performAndWait {
            let _ = mainContext.create(TestEntity.self)
            
            XCTAssertTrue(mainContext.hasChanges)
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
        }
        
        persistenceController.save()
        
        mainContext.performAndWait {
            XCTAssertFalse(mainContext.hasChanges)
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
        }
        
        privateContext.performAndWait {
            XCTAssertFalse(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 1)
        }
    }
    
    func testShouldSaveWhenThereArePendingChangesInThePrivateContext() {
        let mainContext = self.persistenceController.mainContext
        
        guard let privateContext = mainContext.parent else {
            XCTFail("Persistence controller should have a private context.")
            return
        }
        
        mainContext.performAndWait {
            XCTAssertFalse(mainContext.hasChanges)
            XCTAssertEqual(mainContext.count(TestEntity.self), 0)
        }
        
        privateContext.performAndWait {
            let _ = privateContext.create(TestEntity.self)
            
            XCTAssertTrue(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 1)
        }
        
        persistenceController.save()
        
        mainContext.performAndWait {
            XCTAssertFalse(mainContext.hasChanges)
            XCTAssertEqual(mainContext.count(TestEntity.self), 1)
        }
        
        privateContext.performAndWait {
            XCTAssertFalse(privateContext.hasChanges)
            XCTAssertEqual(privateContext.count(TestEntity.self), 1)
        }
    }
    
}
