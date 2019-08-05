import Foundation

public enum PersistenceError: Error {
    
    case objectModelNotFound
    case persistentStoreDescriptionMissing
    case threadConfinementViolation
    
}
