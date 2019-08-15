import Foundation
import CoreData

public enum SQLiteJournalMode: String {
    
    case off = "OFF"
    case writeAheadLog = "WAL"
    case atomicCommitDelete = "DELETE"
    case atomicCommitTruncate = "TRUNCATE"
    case atomicCommitPersist = "PERSIST"
    case atomicCommitMemory = "MEMORY"
    
}

// MARK: -

public extension NSPersistentStoreDescription {
    
    // MARK: - Initializers
    
    convenience init(inMemoryPersistentStoreDescription: ()) {
        self.init(inMemoryPersistentStoreDescriptionForConfiguration: nil)
    }
    
    convenience init(inMemoryPersistentStoreDescriptionForConfiguration configuration: String?, shouldAddStoreAsynchronously: Bool = true, shouldInferMappingModelAutomatically: Bool = true) {
        self.init()
        
        self.type = NSInMemoryStoreType
        self.configuration = configuration
        self.shouldAddStoreAsynchronously = shouldAddStoreAsynchronously
        self.shouldInferMappingModelAutomatically = shouldInferMappingModelAutomatically
    }
    
    convenience init(sqlitePersistentStoreDescriptionWithURL url: URL, errorRecoveryPolicy: ErrorRecoveryPolicy, configuration: String? = nil, isReadOnly: Bool = false, journalMode: SQLiteJournalMode = .writeAheadLog, shouldAddStoreAsynchronously: Bool = true, shouldMigrateStoreAutomatically: Bool = true, shouldInferMappingModelAutomatically: Bool = true) {
        self.init(url: url)
        
        self.type = NSSQLiteStoreType
        self.errorRecoveryPolicy = errorRecoveryPolicy
        self.configuration = configuration
        self.isReadOnly = isReadOnly
        self.shouldAddStoreAsynchronously = shouldAddStoreAsynchronously
        self.shouldMigrateStoreAutomatically = shouldMigrateStoreAutomatically
        self.shouldInferMappingModelAutomatically = shouldInferMappingModelAutomatically
        
        setValue(journalMode.rawValue as NSObject, forPragmaNamed: "journal_mode")
    }

}
