import Foundation

public protocol PPAuthorizer {
    func authorize(completionHandler: @escaping (PPAuthorizerResult) -> Void)
}

public enum PPAuthorizerResult {
    case success(token: String)
    case error(error: Error)
}
