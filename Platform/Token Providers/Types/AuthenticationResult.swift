import Foundation

public enum PPTokenProviderResult {
    
    case success(token: String)
    case error(error: Error)
    
}
