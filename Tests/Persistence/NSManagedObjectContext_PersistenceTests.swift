import XCTest
import CoreData
@testable import PusherPlatform

class NSManagedObjectContext_PersistenceTests: XCTestCase {
    
    // MARK: - Properties
    
    var persistenceController: PersistenceController!
    
    // MARK: - Tests lifecycle
    
    override func setUp() {
        super.setUp()
        
        guard let url = Bundle(for: type(of: self)).url(forResource: "TestModel", withExtension: "momd"), let model = NSManagedObjectModel(contentsOf: url) else {
            assertionFailure("Unable to locate test model.")
            return
        }
        
        let storeDescription = NSPersistentStoreDescription(inMemoryPersistentStoreDescription: ())
        
        let instantiationExpectation = self.expectation(description: "Instantiation")
        
        do {
            self.persistenceController = try PersistenceController(model: model, storeDescriptions: [storeDescription]) { error in
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
        
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let firstEntity = NSEntityDescription.insertNewObject(forEntityName: String(describing: TestEntity.self), into: mainContext) as! TestEntity
            firstEntity.name = "first"
            
            let secondEntity = NSEntityDescription.insertNewObject(forEntityName: String(describing: TestEntity.self), into: mainContext) as! TestEntity
            secondEntity.name = "second"
            
            let thirdEntity = NSEntityDescription.insertNewObject(forEntityName: String(describing: TestEntity.self), into: mainContext) as! TestEntity
            thirdEntity.name = "third"
            
            let fourthEntity = NSEntityDescription.insertNewObject(forEntityName: String(describing: TestEntity.self), into: mainContext) as! TestEntity
            fourthEntity.name = "fourth"
            fourthEntity.relatedEntity = secondEntity
            
            let fifthEntity = NSEntityDescription.insertNewObject(forEntityName: String(describing: TestEntity.self), into: mainContext) as! TestEntity
            fifthEntity.name = "fifth"
            fifthEntity.relatedEntity = thirdEntity
        }
        
        self.persistenceController.save()
    }
    
    // MARK: - Tests
    
    func testShouldCreateNewEntity() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let _ = mainContext.create(TestEntity.self)
            
            let countRequest = NSFetchRequest<TestEntity>(entityName: String(describing: TestEntity.self))
            let count = try! mainContext.count(for: countRequest)
            
            XCTAssertEqual(count, 6)
        }
    }
    
    func testShouldDeleteEntityWithobjectID() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let fetchRequest = NSFetchRequest<TestEntity>(entityName: String(describing: TestEntity.self))
            fetchRequest.predicate = NSPredicate(format: "%K = %@", #keyPath(TestEntity.name), "fourth")
            fetchRequest.fetchLimit = 1
            
            let entity = try! mainContext.fetch(fetchRequest).first!
            
            XCTAssertFalse(entity.isDeleted)
            
            mainContext.delete(with: entity.objectID)
            
            XCTAssertTrue(entity.isDeleted)
            
            let countRequest = NSFetchRequest<TestEntity>(entityName: String(describing: TestEntity.self))
            let count = try! mainContext.count(for: countRequest)
            
            XCTAssertEqual(count, 4)
        }
    }
    
    func testShouldDeleteAllEntities() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            mainContext.deleteAll(TestEntity.self)
            
            let countRequest = NSFetchRequest<TestEntity>(entityName: String(describing: TestEntity.self))
            let count = try! mainContext.count(for: countRequest)
            
            XCTAssertEqual(count, 0)
        }
    }
    
    func testShouldDeleteAllEntitiesMatchingPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let predicate = NSPredicate(format: "%K = %@ OR %K = %@", #keyPath(TestEntity.name), "second", #keyPath(TestEntity.name), "fifth")
            
            mainContext.deleteAll(TestEntity.self, predicate: predicate)
            
            let countRequest = NSFetchRequest<TestEntity>(entityName: String(describing: TestEntity.self))
            let count = try! mainContext.count(for: countRequest)
            
            XCTAssertEqual(count, 3)
        }
    }
    
    func testShouldDeleteAllEntitiesMatchingPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            mainContext.deleteAll(TestEntity.self, predicateFormat: "%K = %@ OR %K = %@ OR %K = %@", #keyPath(TestEntity.name), "first", #keyPath(TestEntity.name), "second", #keyPath(TestEntity.name), "fifth")
            
            let countRequest = NSFetchRequest<TestEntity>(entityName: String(describing: TestEntity.self))
            let count = try! mainContext.count(for: countRequest)
            
            XCTAssertEqual(count, 2)
        }
    }
    
    func testShouldFetchRandomEntity() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entity = mainContext.fetch(TestEntity.self)
            
            XCTAssertNotNil(entity)
        }
    }
    
    func testShouldFetchEntityUsingSortDescriptors() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
            let entity = mainContext.fetch(TestEntity.self, sortDescriptors: [sortDescriptor])
            
            XCTAssertEqual(entity?.name, "third")
        }
    }
    
    func testShouldFetchEntityMatchingPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let predicate = NSPredicate(format: "%K = %@", #keyPath(TestEntity.name), "second")
            let entity = mainContext.fetch(TestEntity.self, predicate: predicate)
            
            XCTAssertEqual(entity?.name, "second")
        }
    }
    
    func testShouldFetchEntityMatchingPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entity = mainContext.fetch(TestEntity.self, predicateFormat: "%K = %@", #keyPath(TestEntity.name), "fifth")
            
            XCTAssertEqual(entity?.name, "fifth")
        }
    }
    
    func testShouldFetchEntityUsingSortDescriptorsAndPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
            let entity = mainContext.fetch(TestEntity.self, sortDescriptors: [sortDescriptor], predicate: predicate)
            
            XCTAssertEqual(entity?.name, "fourth")
        }
    }
    
    func testShouldFetchEntityUsingSortDescriptorsAndPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: true)
            let entity = mainContext.fetch(TestEntity.self, sortDescriptors: [sortDescriptor], predicateFormat: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            
            XCTAssertEqual(entity?.name, "fifth")
        }
    }
    
    func testShouldFetchEntityWithFetchedRelationships() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entity = mainContext.fetch(TestEntity.self, withRelationships: [#keyPath(TestEntity.relatedEntity)], predicateFormat: "%K = %@", #keyPath(TestEntity.name), "second")
            
            guard let relatedEntity = entity?.relatedEntity else {
                XCTFail("Fetched entity should have a realted entity.")
                return
            }
            
            XCTAssertFalse(relatedEntity.isFault)
        }
    }
    
    func testShouldFetchAllEntities() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entities = mainContext.fetchAll(TestEntity.self)
            
            XCTAssertEqual(entities.count, 5)
        }
    }
    
    func testShouldFetchAllEntitiesUsingSortDescriptors() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: true)
            let entities = mainContext.fetchAll(TestEntity.self, sortDescriptors: [sortDescriptor])
            
            XCTAssertEqual(entities.count, 5)
            
            XCTAssertEqual(entities[0].name, "fifth")
            XCTAssertEqual(entities[1].name, "first")
            XCTAssertEqual(entities[2].name, "fourth")
            XCTAssertEqual(entities[3].name, "second")
            XCTAssertEqual(entities[4].name, "third")
        }
    }
    
    func testShouldFetchAllEntitiesUsingFetchLimit() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entities = mainContext.fetchAll(TestEntity.self, fetchLimit: 2)
            
            XCTAssertEqual(entities.count, 2)
        }
    }
    
    func testShouldFetchAllEntitiesMatchingPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            let entities = mainContext.fetchAll(TestEntity.self, predicate: predicate)
            
            XCTAssertEqual(entities.count, 3)
        }
    }
    
    func testShouldFetchAllEntitiesMatchingPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entities = mainContext.fetchAll(TestEntity.self, predicateFormat: "%K ENDSWITH[c] %@", #keyPath(TestEntity.name), "h")
            
            XCTAssertEqual(entities.count, 2)
        }
    }
    
    func testShouldFetchAllEntitiesUsingSortDescriptorsAndFetchLimit() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
            let entities = mainContext.fetchAll(TestEntity.self, sortDescriptors: [sortDescriptor], fetchLimit: 2)
            
            XCTAssertEqual(entities.count, 2)
            
            XCTAssertEqual(entities[0].name, "third")
            XCTAssertEqual(entities[1].name, "second")
        }
    }
    
    func testShouldFetchAllEntitiesUsingSortDescriptorsAndPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
            let predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            let entities = mainContext.fetchAll(TestEntity.self, sortDescriptors: [sortDescriptor], predicate: predicate)
            
            XCTAssertEqual(entities.count, 3)
            
            XCTAssertEqual(entities[0].name, "fourth")
            XCTAssertEqual(entities[1].name, "first")
            XCTAssertEqual(entities[2].name, "fifth")
        }
    }
    
    func testShouldFetchAllEntitiesUsingSortDescriptorsAndPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: true)
            let entities = mainContext.fetchAll(TestEntity.self, sortDescriptors: [sortDescriptor], predicateFormat: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            
            XCTAssertEqual(entities.count, 3)
            
            XCTAssertEqual(entities[0].name, "fifth")
            XCTAssertEqual(entities[1].name, "first")
            XCTAssertEqual(entities[2].name, "fourth")
        }
    }
    
    func testShouldFetchAllEntitiesMatchingFetchLimitAndPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            let entities = mainContext.fetchAll(TestEntity.self, fetchLimit: 2, predicate: predicate)
            
            XCTAssertEqual(entities.count, 2)
            
            let acceptableResults: Set = ["first", "fourth", "fifth"]
            
            guard let firstResultName = entities.first?.name, let secondResultName = entities.last?.name else {
                XCTFail("Fetch results should contain excatly two entities.")
                return
            }
            
            XCTAssertTrue(acceptableResults.contains(firstResultName))
            XCTAssertTrue(acceptableResults.contains(secondResultName))
        }
    }
    
    func testShouldFetchAllEntitiesMatchingFetchLimitAndPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entities = mainContext.fetchAll(TestEntity.self, fetchLimit: 2, predicateFormat: "%K CONTAINS[c] %@", #keyPath(TestEntity.name), "h")
            
            XCTAssertEqual(entities.count, 2)
            
            let acceptableResults: Set = ["third", "fourth", "fifth"]
            
            guard let firstResultName = entities.first?.name, let secondResultName = entities.last?.name else {
                XCTFail("Fetch results should contain excatly two entities.")
                return
            }
            
            XCTAssertTrue(acceptableResults.contains(firstResultName))
            XCTAssertTrue(acceptableResults.contains(secondResultName))
        }
    }
    
    func testShouldFetchAllEntitiesUsingSortDescriptorsFetchLimitAndPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
            let predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            let entities = mainContext.fetchAll(TestEntity.self, sortDescriptors: [sortDescriptor], fetchLimit: 2, predicate: predicate)
            
            XCTAssertEqual(entities.count, 2)
            
            XCTAssertEqual(entities[0].name, "fourth")
            XCTAssertEqual(entities[1].name, "first")
        }
    }
    
    func testShouldFetchAllEntitiesUsingSortDescriptorsFetchLimitAndPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let sortDescriptor = NSSortDescriptor(key: #keyPath(TestEntity.name), ascending: false)
            let entities = mainContext.fetchAll(TestEntity.self, sortDescriptors: [sortDescriptor], fetchLimit: 2, predicateFormat: "%K CONTAINS[c] %@", #keyPath(TestEntity.name), "h")
            
            XCTAssertEqual(entities.count, 2)
            
            XCTAssertEqual(entities[0].name, "third")
            XCTAssertEqual(entities[1].name, "fourth")
        }
    }
    
    func testShouldFetchAllEntitiesWithFetchedRelationships() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let entities = mainContext.fetchAll(TestEntity.self, withRelationships: [#keyPath(TestEntity.relatedEntity)], predicateFormat: "%K != NULL", #keyPath(TestEntity.relatedEntity))
            
            XCTAssertEqual(entities.count, 4)
            
            guard let firstRelatedEntity = entities[0].relatedEntity,
                let secondRelatedEntity = entities[1].relatedEntity,
                let thirdRelatedEntity = entities[2].relatedEntity,
                let fourthRelatedEntity = entities[3].relatedEntity else {
                XCTFail("Fetched entities should have a realted entity.")
                return
            }
            
            XCTAssertFalse(firstRelatedEntity.isFault)
            XCTAssertFalse(secondRelatedEntity.isFault)
            XCTAssertFalse(thirdRelatedEntity.isFault)
            XCTAssertFalse(fourthRelatedEntity.isFault)
            
        }
    }
    
    func testShouldCountAllEntities() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let count = mainContext.count(TestEntity.self)
            
            XCTAssertEqual(count, 5)
        }
    }
    
    func testShouldCountAllEntitiesMatchingPredicate() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let predicate = NSPredicate(format: "%K BEGINSWITH[c] %@", #keyPath(TestEntity.name), "f")
            let count = mainContext.count(TestEntity.self, predicate: predicate)
            
            XCTAssertEqual(count, 3)
        }
    }
    
    func testShouldCountAllEntitiesMatchingPredicateFormat() {
        let mainContext = self.persistenceController.mainContext
        
        mainContext.performAndWait {
            let count = mainContext.count(TestEntity.self, predicateFormat: "%K CONTAINS[c] %@", #keyPath(TestEntity.name), "o")
            
            XCTAssertEqual(count, 2)
        }
    }
    
}
