import XCTest
import CoreData
@testable import PusherPlatform

class ChangeControllerTests: XCTestCase {
    
    // MARK: - Properties
    
    var persistenceController: PersistenceController!
    var changeController: ChangeController<TestEntity>!
    
    var sortDescriptors: [NSSortDescriptor]!
    var predicate: NSPredicate!
    var logger: PPLogger!
    
    // MARK: - Tests lifecycle
    
    override func setUp() {
        super.setUp()
        
        guard let url = Bundle(for: type(of: self)).url(forResource: "TestModel", withExtension: "momd"), let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Unable to locate test model.")
        }
        
        let storeDescription = NSPersistentStoreDescription(inMemoryPersistentStoreDescription: ())
        
        self.logger = PPDefaultLogger()
        
        let instantiationExpectation = self.expectation(description: "Instantiation")
        
        do {
            self.persistenceController = try PersistenceController(model: model, storeDescriptions: [storeDescription], logger: self.logger) { error in
                guard error == nil else {
                    fatalError("Failed to create in-memory store.")
                }
                
                instantiationExpectation.fulfill()
            }
        } catch {
            fatalError("Failed to instantiat persistence controller.")
        }
        
        waitForExpectations(timeout: 5.0)
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            let firstEntity = context.create(TestEntity.self)
            firstEntity.name = "Aaron"
            
            let secondEntity = context.create(TestEntity.self)
            secondEntity.name = "Alexa"
            
            let thirdEntity = context.create(TestEntity.self)
            thirdEntity.name = "Aurelia"
            
            let fourthEntity = context.create(TestEntity.self)
            fourthEntity.name = "Bob"
            
            self.persistenceController.save()
        }
        
        let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
        self.sortDescriptors = [sortDescriptor]
        
        self.predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "A")
        
        self.changeController = ChangeController(sortDescriptors: self.sortDescriptors,
                                                 predicate: self.predicate,
                                                 fetchBatchSize: 10,
                                                 context: self.persistenceController.mainContext,
                                                 logger: self.logger)
    }
    
    // MARK: - Tests
    
    func testShouldHaveCorrectSortDescriptors() {
        XCTAssertEqual(self.changeController.sortDescriptors, self.sortDescriptors)
    }
    
    func testShouldHaveCorrectPredicate() {
        XCTAssertEqual(self.changeController.predicate, self.predicate)
    }
    
    func testShouldNotHavePredicateByDefault() {
        let changeController = ChangeController<TestEntity>(sortDescriptors: self.sortDescriptors,
                                                            fetchBatchSize: 10,
                                                            context: self.persistenceController.mainContext,
                                                            logger: self.logger)
        
        XCTAssertNil(changeController.predicate)
    }
    
    func testShouldHaveCorrectFetchBatchSize() {
        XCTAssertEqual(self.changeController.fetchBatchSize, 10)
    }
    
    func testShouldHaveCorrectDefaultFetchBatchSize() {
        let changeController = ChangeController<TestEntity>(sortDescriptors: self.sortDescriptors,
                                                            predicate: self.predicate,
                                                            context: self.persistenceController.mainContext,
                                                            logger: self.logger)
        
        XCTAssertEqual(changeController.fetchBatchSize, 50)
    }
    
    func testShouldHaveLogger() {
        XCTAssertNotNil(self.changeController.logger)
    }
    
    func testShouldNotHaveLoggerByDefault() {
        let changeController = ChangeController<TestEntity>(sortDescriptors: self.sortDescriptors,
                                                            predicate: self.predicate,
                                                            fetchBatchSize: 10,
                                                            context: self.persistenceController.mainContext)
        
        XCTAssertNil(changeController.logger)
    }
    
    func testShouldHaveCorrectContext() {
        XCTAssertEqual(self.changeController.context, self.persistenceController.mainContext)
    }
    
    func testShouldHaveCorrectEntityName() {
        let changeController = ChangeController<TestEntity>(entityName: "TestEntity",
                                                            sortDescriptors: self.sortDescriptors,
                                                            predicate: self.predicate,
                                                            fetchBatchSize: 10,
                                                            context: self.persistenceController.mainContext,
                                                            logger: self.logger)
        
        XCTAssertEqual(changeController.entityName, String(describing: TestEntity.self))
    }
    
    func testShouldHaveCorrectDefaultEntityName() {
        XCTAssertEqual(self.changeController.entityName, String(describing: TestEntity.self))
    }
    
    func testShouldSetDelegate() {
        let delegate = TestChangeControllerDelegate<TestEntity>()
        self.changeController.delegate = delegate
        
        XCTAssertNotNil(self.changeController.delegate)
    }
    
    func testShouldNotHaveDelegateByDefault() {
        XCTAssertNil(self.changeController.delegate)
    }
    
    func testShouldHaveCorrectNumberOfObjects() {
        XCTAssertEqual(self.changeController.numberOfObjects, 3)
    }
    
    func testShouldHaveCorrectObjectsOrderedUsingSortDescriptors() {
        XCTAssertEqual(self.changeController.objects.count, 3)
        XCTAssertEqual(self.changeController.objects[0].name, "Aurelia")
        XCTAssertEqual(self.changeController.objects[1].name, "Alexa")
        XCTAssertEqual(self.changeController.objects[2].name, "Aaron")
    }
    
    func testShouldReturnCorrectObjectAtProvidedIndex() {
        XCTAssertEqual(self.changeController.object(at: 2)?.name, "Aaron")
    }
    
    func testShouldNotReturnObjectForOutOfBoundsIndex() {
        XCTAssertNil(self.changeController.object(at: 3))
    }
    
    func testShouldReturnCorrectIndexForProvidedObject() {
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let object = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Alexa") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            XCTAssertEqual(self.changeController.index(for: object), 1)
        }
    }
    
    func testShouldNotReturnIndexForNotManagedObject() {
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let object = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Bob") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            XCTAssertNil(self.changeController.index(for: object))
        }
    }
    
    func testShouldNotifyAboutInsertedObjectsIncludedByPredicate() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(insertCallback: { objects, indexes in
            XCTAssertEqual(objects.count, 2)
            XCTAssertEqual(objects.first?.name, "Ash")
            XCTAssertEqual(objects.last?.name, "Abby")
            
            XCTAssertEqual(indexes.count, 2)
            XCTAssertEqual(indexes.first, 1)
            XCTAssertEqual(indexes.last, 3)
            
            expectation.fulfill()
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            let firstEntity = context.create(TestEntity.self)
            firstEntity.name = "Abby"
            
            let secondEntity = context.create(TestEntity.self)
            secondEntity.name = "Ash"
            
            self.persistenceController.save()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotNotifyAboutInsertedObjectsNotIncludedByPredicate() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(insertCallback: { _, _ in
            XCTFail("Delegate method should not be called.")
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            let entity = context.create(TestEntity.self)
            entity.name = "George"
            
            self.persistenceController.save() { _ in
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotifyAboutUpdatedObject() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(updateCallback: { object, index in
            XCTAssertEqual(object.name, "Abby")
            XCTAssertEqual(index, 2)
            
            guard let originalValue = object.changedValuesForCurrentEvent()[#keyPath(TestEntity.name)] as? String else {
                XCTFail("Object should contain original value.")
                return
            }
            
            XCTAssertEqual(originalValue, "Aaron")
            
            expectation.fulfill()
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let entity = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Aaron") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            entity.name = "Abby"
            
            self.persistenceController.save()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotifyAboutInsertedObjectWhenUpdatingObjectInitialyNotIncludedByPredicate() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(insertCallback: { objects, indexes in
            XCTAssertEqual(objects.count, 1)
            XCTAssertEqual(objects.first?.name, "Abby")
            
            XCTAssertEqual(indexes.count, 1)
            XCTAssertEqual(indexes.first, 2)
            
            guard let originalValue = objects.first?.changedValuesForCurrentEvent()[#keyPath(TestEntity.name)] as? String else {
                XCTFail("Object should contain original value.")
                return
            }
            
            XCTAssertEqual(originalValue, "Bob")
            
            expectation.fulfill()
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let entity = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Bob") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            entity.name = "Abby"
            
            self.persistenceController.save()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotifyAboutDeletedObjectWhenUpdatingObjectInitialyIncludedByPredicate() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(deleteCallback: { object, index in
            XCTAssertEqual(object.name, "George")
            XCTAssertEqual(index, 1)
            
            guard let originalValue = object.changedValuesForCurrentEvent()[#keyPath(TestEntity.name)] as? String else {
                XCTFail("Object should contain original value.")
                return
            }
            
            XCTAssertEqual(originalValue, "Alexa")
            
            expectation.fulfill()
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let entity = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Alexa") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            entity.name = "George"
            
            self.persistenceController.save()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotifyAboutMovedObject() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(moveCallback: { object, oldIndex, newIndex in
            XCTAssertEqual(object.name, "Abby")
            XCTAssertEqual(oldIndex, 0)
            XCTAssertEqual(newIndex, 1)
            
            guard let originalValue = object.changedValuesForCurrentEvent()[#keyPath(TestEntity.name)] as? String else {
                XCTFail("Object should contain original value.")
                return
            }
            
            XCTAssertEqual(originalValue, "Aurelia")
            
            expectation.fulfill()
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let entity = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Aurelia") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            entity.name = "Abby"
            
            self.persistenceController.save()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotifyAboutDeletedObjectWhenObjectInitialyIncludedByPredicate() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(deleteCallback: { object, index in
            XCTAssertEqual(object.name, "Aurelia")
            XCTAssertEqual(index, 0)
            
            expectation.fulfill()
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let entity = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Aurelia") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            context.delete(entity)
            
            self.persistenceController.save()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldNotNotifyAboutDeletedObjectWhenObjectNotInitialyIncludedByPredicate() {
        let expectation = self.expectation(description: "Delegate Notification")
        
        let delegate = TestChangeControllerDelegate<TestEntity>(deleteCallback: { _, _ in
            XCTFail("Delegate method should not be called.")
        })
        self.changeController.delegate = delegate
        
        let context = self.persistenceController.mainContext
        
        context.performAndWait {
            guard let entity = context.fetch(TestEntity.self, filteredBy: "%K == %@", #keyPath(TestEntity.name), "Bob") else {
                XCTFail("Context should contain test entity.")
                return
            }
            
            context.delete(entity)
            
            self.persistenceController.save() { _ in
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
}
