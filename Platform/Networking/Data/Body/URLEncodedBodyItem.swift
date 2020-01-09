import Foundation

/// A single name-value pair from the URL encoded body of a request.
public struct URLEncodedBodyItem {
    
    // MARK: - Properties
    
    /// The name of the body item.
    public let name: String
    
    /// The value of the body item.
    public let value: String
    
    // MARK: - Initializers
    
    /// Create an URL encoded body item.
    ///
    /// - Parameters:
    ///     - name: The name of the body item.
    ///     - value: The value of the body item.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
    
    init(name: Name, value: Value) {
        self.init(name: name.rawValue, value: value.rawValue)
    }
    
}

// MARK: - Name

internal extension URLEncodedBodyItem {
    
    enum Name: String {
        
        case grantType = "grant_type"
        
    }
    
}

// MARK: - Value

internal extension URLEncodedBodyItem {
    
    enum Value: String {
        
        case clientCredentials = "client_credentials"
        
    }
    
}
