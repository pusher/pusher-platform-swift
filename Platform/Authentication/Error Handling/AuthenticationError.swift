import Foundation

/// Enumeration that represents authentication error.
public enum AuthenticationError: Error {
    
    /// The URL provided to `TokenProvider` has invalid format.
    case invalidURL
    
    /// Failed to serialize the request body while trying to fetch a new token.
    case failedToSerializeBody
    
    /// Failed to pase the token received from the web service.
    case failedToParseToken
    
}
