import Foundation
import PusherPlatform

extension URL {
    
    // MARK: - Properties
    
    private static let hostname = "pusherplatform.io"
    private static let tokenProviderService = "services/chatkit_token_provider"
    private static let tokenProviderResource = "token"
    
    // MARK: - Initializers
    
    init(tokenProviderURLFor instanceLocator: String) {
        guard let instanceLocator = InstanceLocator(string: instanceLocator) else {
            preconditionFailure("Invalid format of the provided instance locator.")
        }
        
        let path = "\(URL.tokenProviderService)/\(instanceLocator.version)/\(instanceLocator.identifier)/\(URL.tokenProviderResource)"
        
        guard let url = URL(string: path, relativeTo: URL(baseURLFor: instanceLocator))?.absoluteURL else {
            preconditionFailure("Failed to create token provider URL from the provided instance locator.")
        }
        
        self = url
    }
    
    private init(baseURLFor instanceLocator: InstanceLocator) {
        guard let url = URL(string: "https://\(instanceLocator.region).\(URL.hostname)") else {
            preconditionFailure("Failed to create base URL from the provided instance locator.")
        }
        
        self = url
    }
    
}
