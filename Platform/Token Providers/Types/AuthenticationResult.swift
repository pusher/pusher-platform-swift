import Foundation

public enum AuthenticationResult {
    
    case authenticated(token: Token)
    case failure(error: Error)
    
}
