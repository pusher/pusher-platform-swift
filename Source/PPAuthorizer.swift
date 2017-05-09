import Foundation

public protocol PPAuthorizer {
    func authorize(completionHandler: @escaping (Result<String>) -> Void) -> Void
}
