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
    
    func deleteAll<T: NSManagedObject>(_ entity: T.Type, filteredBy predicate: NSPredicate? = nil) {
        let objects = fetchAll(entity, filteredBy: predicate)
        
        for object in objects {
            delete(object)
        }
    }
    
    func deleteAll<T: NSManagedObject>(_ entity: T.Type, filteredBy predicateFormat: String, _ predicateArguments: CVarArg...) {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        deleteAll(entity, filteredBy: predicate)
    }
    
    func fetch<T: NSManagedObject>(_ entity: T.Type, withRelationships relationships: [String]? = nil, sortedBy sortDescriptors: [NSSortDescriptor]? = nil, filteredBy predicate: NSPredicate? = nil) -> T? {
        return fetchAll(entity, withRelationships: relationships, sortedBy: sortDescriptors, filteredBy: predicate).first
    }
    
    func fetch<T: NSManagedObject>(_ entity: T.Type, withRelationships relationships: [String]? = nil, sortedBy sortDescriptors: [NSSortDescriptor]? = nil, filteredBy predicateFormat: String, _ predicateArguments: CVarArg...) -> T? {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        return fetch(entity, withRelationships: relationships, sortedBy: sortDescriptors, filteredBy: predicate)
    }
    
    func fetchAll<T: NSManagedObject>(_ entity: T.Type, withRelationships relationships: [String]? = nil, limit: Int = 0, sortedBy sortDescriptors: [NSSortDescriptor]? = nil, filteredBy predicate: NSPredicate? = nil) -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.relationshipKeyPathsForPrefetching = relationships
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.fetchLimit = limit
        fetchRequest.predicate = predicate
        
        return (try? fetch(fetchRequest)) ?? [T]()
    }
    
    func fetchAll<T: NSManagedObject>(_ entity: T.Type, withRelationships relationships: [String]? = nil, limit: Int = 0, sortedBy sortDescriptors: [NSSortDescriptor]? = nil, filteredBy predicateFormat: String, _ predicateArguments: CVarArg...) -> [T] {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        return fetchAll(entity, withRelationships: relationships, limit: limit, sortedBy: sortDescriptors, filteredBy: predicate)
    }
    
    func count<T: NSManagedObject>(_ entity: T.Type, filteredBy predicate: NSPredicate? = nil) -> Int {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.predicate = predicate
        
        return (try? count(for: fetchRequest)) ?? 0
    }
    
    func count<T: NSManagedObject>(_ entity: T.Type, filteredBy predicateFormat: String, _ predicateArguments: CVarArg...) -> Int {
        var predicate: NSPredicate? = nil
        
        withVaList(predicateArguments) { arguments in
            predicate = NSPredicate(format: predicateFormat, arguments: arguments)
        }
        
        return count(entity, filteredBy: predicate)
    }
    
}
