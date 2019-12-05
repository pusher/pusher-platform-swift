import Foundation
import CoreData
@testable import PusherPlatform

class TestChangeControllerDelegate<T>: ChangeControllerDelegate where T: NSManagedObject {
    
    // MARK: - Types
    
    typealias InsertCallback = ([T], IndexSet) -> Void
    typealias UpdateCallback = (T, Int) -> Void
    typealias MoveCallback = (T, Int, Int) -> Void
    typealias DeleteCallback = (T, Int) -> Void
    
    // MARK: - Properties
    
    let insertCallback: InsertCallback?
    let updateCallback: UpdateCallback?
    let moveCallback: MoveCallback?
    let deleteCallback: DeleteCallback?
    
    // MARK: - Initializers
    
    init(insertCallback: InsertCallback? = nil, updateCallback: UpdateCallback? = nil, moveCallback: MoveCallback? = nil, deleteCallback: DeleteCallback? = nil) {
        self.insertCallback = insertCallback
        self.updateCallback = updateCallback
        self.moveCallback = moveCallback
        self.deleteCallback = deleteCallback
    }
    
    // MARK: - ChangeControllerDelegate
    
    func changeController<ResultType>(_ changeController: ChangeController<ResultType>, didInsertObjects objects: [ResultType], at indexes: IndexSet) where ResultType : NSManagedObject {
        guard let insertCallback = self.insertCallback, let objects = objects as? [T] else {
            return
        }
        
        insertCallback(objects, indexes)
    }
    
    func changeController<ResultType>(_ changeController: ChangeController<ResultType>, didUpdateObject object: ResultType, at index: Int) where ResultType : NSManagedObject {
        guard let updateCallback = self.updateCallback, let object = object as? T else {
            return
        }
        
        updateCallback(object, index)
    }
    
    func changeController<ResultType>(_ changeController: ChangeController<ResultType>, didMoveObject object: ResultType, from oldIndex: Int, to newIndex: Int) where ResultType : NSManagedObject {
        guard let moveCallback = self.moveCallback, let object = object as? T else {
            return
        }
        
        moveCallback(object, oldIndex, newIndex)
    }
    
    func changeController<ResultType>(_ changeController: ChangeController<ResultType>, didDeleteObject object: ResultType, at index: Int) where ResultType : NSManagedObject {
        guard let deleteCallback = self.deleteCallback, let object = object as? T else {
            return
        }
        
        deleteCallback(object, index)
    }
    
}
