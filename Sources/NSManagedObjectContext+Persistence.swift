import Foundation
import CoreData

public extension NSManagedObjectContext {
    
    // MARK: - Public methods

    func create<T: NSManagedObject>(_ entity: T.Type) -> T {
        return NSEntityDescription.insertNewObject(forEntityName: String(describing: T.self), into: self) as! T
    }
    
    func delete(with objectID: NSManagedObjectID) {
        guard let object = try? existingObject(with: objectID) else {
            return
        }
        
        delete(object)
    }
    
    func deleteAll<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate? = nil) {
        let objects = fetchAll(entity, predicate: predicate)
        
        for object in objects {
            delete(object)
        }
    }
    
    func deleteAll<T: NSManagedObject>(_ entity: T.Type, predicateFormat: String, _ predicateArguments: CVarArg...) {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        deleteAll(entity, predicate: predicate)
    }
    
    func fetch<T: NSManagedObject>(_ entity: T.Type, sortDescriptors: [NSSortDescriptor]? = nil, predicate: NSPredicate? = nil) -> T? {
        return fetchAll(entity, sortDescriptors: sortDescriptors, predicate: predicate).first
    }
    
    func fetch<T: NSManagedObject>(_ entity: T.Type, sortDescriptors: [NSSortDescriptor]? = nil, predicateFormat: String, _ predicateArguments: CVarArg...) -> T? {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        return fetch(entity, sortDescriptors: sortDescriptors, predicate: predicate)
    }
    
    func fetchAll<T: NSManagedObject>(_ entity: T.Type, sortDescriptors: [NSSortDescriptor]? = nil, fetchLimit: Int = 0, predicate: NSPredicate? = nil) -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchLimit = fetchLimit
        fetchRequest.predicate = predicate
        
        return (try? fetch(fetchRequest)) ?? [T]()
    }
    
    func fetchAll<T: NSManagedObject>(_ entity: T.Type, sortDescriptors: [NSSortDescriptor]? = nil, fetchLimit: Int = 0, predicateFormat: String, _ predicateArguments: CVarArg...) -> [T] {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        return fetchAll(entity, sortDescriptors: sortDescriptors, fetchLimit: fetchLimit, predicate: predicate)
    }
    
    func count<T: NSManagedObject>(_ entity: T.Type, predicate: NSPredicate? = nil) -> Int {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.predicate = predicate
        
        return (try? count(for: fetchRequest)) ?? 0
    }
    
    func count<T: NSManagedObject>(_ entity: T.Type, predicateFormat: String, _ predicateArguments: CVarArg...) -> Int {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        return count(entity, predicate: predicate)
    }
    
}
