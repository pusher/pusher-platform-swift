import Foundation

/// Protocol defining the interface required to be implemented in order to obtain JWT token used by the SDK
/// to access Pusher web services.
public protocol TokenProvider {
    
    // MARK: - Methods
    
    /// Method called by the SDK to authenticate the user.
    ///
    /// - Parameters:
    ///     - completionHandler: The completion handler that provides
    ///     `AuthenticationResult` to the SDK.
    func fetchToken(completionHandler: @escaping (AuthenticationResult) -> Void)
    
}
