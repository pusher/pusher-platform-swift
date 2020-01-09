import Foundation

/// Protocol defining the interface that represent a token used by the SDK to access Pusher web services.
public protocol Token {
    
    // MARK: - Properties
    
    /// String representation of the token.
    var token: String { get }
    
    /// Expiration date of the token.
    var expiryDate: Date { get }
    
}

// MARK: - Validation

internal extension Token {
    
    // MARK: - Accessors
    
    var isExpired: Bool {
        let now = Date()
        
        return self.expiryDate < now
    }
    
}
