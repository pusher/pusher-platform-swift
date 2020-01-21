import Foundation

/// Enumeration that represents the result of the authentication process.
public enum AuthenticationResult {
    
    /// Value representing successful authentication.
    ///
    /// - Parameters:
    ///     - token: Token received during the authentication process.
    case authenticated(token: Token)
    
    /// Value representing failed authentication.
    ///
    /// - Parameters:
    ///     - error: Error representing the reson of the authentication failure.
    case failure(error: Error)
    
}
