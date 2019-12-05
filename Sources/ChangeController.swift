import Foundation
import CoreData

public class ChangeController<ResultType> where ResultType: NSManagedObject {
    
    // MARK: - Properties
    
    public let sortDescriptors: [NSSortDescriptor]
    public let logger: PPLogger?
    
    weak var delegate: ChangeControllerDelegate?
    
    private let wrapper: FetchedResultsControllerWrapper<ResultType>
    private var insertions: IndexSet
    
    // MARK: - Accessors
    
    public var context: NSManagedObjectContext {
        return wrapper.fetchedResultsController.managedObjectContext
    }
    
    public var entityName: String {
        return wrapper.fetchedResultsController.fetchRequest.entityName ?? String(describing: ResultType.self)
    }
    
    public var predicate: NSPredicate? {
        return wrapper.fetchedResultsController.fetchRequest.predicate
    }
    
    public var fetchBatchSize: Int {
        return wrapper.fetchedResultsController.fetchRequest.fetchBatchSize
    }
    
    public var numberOfObjects: Int {
        return wrapper.fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    public var objects: [ResultType] {
        return wrapper.fetchedResultsController.fetchedObjects ?? []
    }
    
    // MARK: - Initializers
    
    public init(entityName: String, sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, fetchBatchSize: Int = 50, context: NSManagedObjectContext, logger: PPLogger? = nil) {
        self.logger = logger
        self.sortDescriptors = sortDescriptors
        self.insertions = IndexSet()
        
        let fetchRequest = NSFetchRequest<ResultType>(entityName: entityName)
        fetchRequest.fetchBatchSize = fetchBatchSize
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        
        self.wrapper = FetchedResultsControllerWrapper(fetchedResultsController: fetchedResultsController)
        self.wrapper.delegate = self
        
        self.performFetch()
    }
    
    public convenience init(sortDescriptors: [NSSortDescriptor], predicate: NSPredicate? = nil, fetchBatchSize: Int = 50, context: NSManagedObjectContext, logger: PPLogger? = nil) {
        let entityName = String(describing: ResultType.self)
        self.init(entityName: entityName, sortDescriptors: sortDescriptors, predicate: predicate, fetchBatchSize: fetchBatchSize, context: context, logger: logger)
    }
    
    // MARK: - Public methods
    
    public func object(at index: Int) -> ResultType? {
        guard index < numberOfObjects else {
            return nil
        }
        
        let indexPath = IndexPath(item: index, section: 0)
        return wrapper.fetchedResultsController.object(at: indexPath)
    }
    
    public func index(for object: ResultType) -> Int? {
        let indexPath = wrapper.fetchedResultsController.indexPath(forObject: object)
        return indexPath?.item
    }
    
    // MARK: - Private methods
    
    private func performFetch() {
        do {
            try wrapper.fetchedResultsController.performFetch()
        } catch {
            logger?.log("Failed to perform fetch using the provided parameters.", logLevel: .warning)
        }
    }
    
    private func commitInsertions() {
        guard !insertions.isEmpty else {
            return
        }
        
        let insertedObjects = insertions.map { objects[$0] }
        
        delegate?.changeController(self, didInsertObjects: insertedObjects, at: insertions)
        
        insertions.removeAll()
    }
    
}

// MARK: - Wrapper delegate

extension ChangeController: FetchedResultsControllerWrapperDelegate {
    
    func fetchedResultsControllerWrapper<T>(_ fetchedResultsControllerWrapper: FetchedResultsControllerWrapper<T>, didChange object: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) where T : NSManagedObject {
        guard let object = object as? ResultType else {
            return
        }
        
        switch type {
        case .insert:
            guard let index = newIndexPath?.item else {
                return
            }
            
            insertions.insert(index)
        
        case .update:
            guard let index = indexPath?.item else {
                return
            }
            
            delegate?.changeController(self, didUpdateObject: object, at: index)
            
        case .move:
            guard let oldIndex = indexPath?.item, let newIndex = newIndexPath?.item else {
                return
            }
            
            delegate?.changeController(self, didMoveObject: object, from: oldIndex, to: newIndex)
        
        case .delete:
            guard let index = indexPath?.item else {
                return
            }
            
            delegate?.changeController(self, didDeleteObject: object, at: index)
        }
    }
    
    func fetchedResultsControllerWrapperDidChangeContent<T>(_ fetchedResultsControllerWrapper: FetchedResultsControllerWrapper<T>) where T : NSManagedObject {
        commitInsertions()
    }
    
}

// MARK: - Delegate

public protocol ChangeControllerDelegate: class {
    
    func changeController<ResultType: NSManagedObject>(_ changeController: ChangeController<ResultType>, didInsertObjects objects: [ResultType], at indexes: IndexSet)
    func changeController<ResultType: NSManagedObject>(_ changeController: ChangeController<ResultType>, didUpdateObject object: ResultType, at index: Int)
    func changeController<ResultType: NSManagedObject>(_ changeController: ChangeController<ResultType>, didMoveObject object: ResultType, from oldIndex: Int, to newIndex: Int)
    func changeController<ResultType: NSManagedObject>(_ changeController: ChangeController<ResultType>, didDeleteObject object: ResultType, at index: Int)
    
}
