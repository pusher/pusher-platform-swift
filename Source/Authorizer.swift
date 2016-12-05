import PromiseKit

public protocol Authorizer {
    func authorize() -> Promise<String>
}
