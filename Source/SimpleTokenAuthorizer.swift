import Foundation

@objc public class SimpleTokenAuthorizer: NSObject, Authorizer {
    public var jwt: String

    public init(jwt: String) {
        self.jwt = jwt
    }

    public func authorize(completionHandler: @escaping (Result<String>) -> Void) -> Void {
        completionHandler(.success(self.jwt))
    }
}
