import Foundation

struct Header {}

// MARK: - Field

extension Header {
    
    enum Field: String {
        
        case contentType = "Content-Type"
        
    }
    
}

// MARK: - Value

extension Header {
    
    enum Value: String {
        
        case applicationFormURLEncoded = "application/x-www-form-urlencoded"
        
    }
    
}
