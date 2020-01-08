import Foundation

public protocol TokenProvider {
    
    func fetchToken(completionHandler: @escaping (AuthenticationResult) -> Void)
    
}
