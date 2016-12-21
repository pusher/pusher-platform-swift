import Foundation

public protocol Authorizer {
    func authorize(completionHandler: @escaping (Result<String>) -> Void) -> Void
}
