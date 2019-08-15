import Foundation

public enum ErrorRecoveryPolicy {
    
    case fail
    case deleteStore
    case backupStore(URL)
    
}

// MARK: - Equatable

extension ErrorRecoveryPolicy: Equatable {
    
    public static func == (lhs: ErrorRecoveryPolicy, rhs: ErrorRecoveryPolicy) -> Bool {
        switch (lhs, rhs) {
        case (.fail, .fail),
             (.deleteStore, .deleteStore):
            return true
            
        case let (.backupStore(lhsURL), .backupStore(rhsURL)):
            return lhsURL == rhsURL
            
        default:
            return false
        }
    }
    
}
