import Foundation
import CoreData

public extension NSPersistentStoreDescription {
    
    // MARK: - Types
    
    private struct AssociatedKeys {
        
        // MARK: - Properties
        
        static var errorRecoveryPolicy: UInt8 = 0
        
    }
    
    // MARK: - Properties
    
    var errorRecoveryPolicy: ErrorRecoveryPolicy {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.errorRecoveryPolicy) as? ErrorRecoveryPolicy ?? .fail
        }
        
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.errorRecoveryPolicy, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Internal methods
    
    func attemptRecovery() {
        let fileManager = FileManager.default
        
        guard let url = url, fileManager.fileExists(atPath: url.path) else {
            return
        }
        
        switch errorRecoveryPolicy {
        case .deleteStore:
            try? fileManager.removeItem(at: url)
            
        case let .backupStore(backupURL):
            if fileManager.fileExists(atPath: backupURL.path) {
                try? fileManager.removeItem(at: backupURL)
            }
            
            try? fileManager.moveItem(at: url, to: backupURL)
            
        case .fail:
            // Do not attempt to recover.
            break
        }
    }
    
}
