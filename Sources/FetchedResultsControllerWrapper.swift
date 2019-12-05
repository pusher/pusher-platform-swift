import Foundation
import CoreData

class FetchedResultsControllerWrapper<ResultType>: NSObject, NSFetchedResultsControllerDelegate where ResultType: NSManagedObject {
    
    // MARK: - Properties
    
    let fetchedResultsController: NSFetchedResultsController<ResultType>
    
    weak var delegate: FetchedResultsControllerWrapperDelegate?
    
    // MARK: - Initializers
    
    init(fetchedResultsController: NSFetchedResultsController<ResultType>) {
        self.fetchedResultsController = fetchedResultsController
        
        super.init()
        
        self.fetchedResultsController.delegate = self
    }
    
    // MARK: - NSFetchedResultsControllerDelegate
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        delegate?.fetchedResultsControllerWrapper(self, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        delegate?.fetchedResultsControllerWrapperDidChangeContent(self)
    }
    
}

// MARK: - Delegate

protocol FetchedResultsControllerWrapperDelegate: class {
    
    func fetchedResultsControllerWrapper<ResultType: NSManagedObject>(_ fetchedResultsControllerWrapper: FetchedResultsControllerWrapper<ResultType>, didChange object: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    func fetchedResultsControllerWrapperDidChangeContent<ResultType: NSManagedObject>(_ fetchedResultsControllerWrapper: FetchedResultsControllerWrapper<ResultType>)
    
}
