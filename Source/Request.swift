import Foundation

@objc public class GeneralRequest: NSObject {
    public let method: String
    public var path: String
    public internal(set) var queryItems: [URLQueryItem]
    public internal(set) var headers: [String: String]
    public let body: Data?

    public init(method: String, path: String, queryItems: [URLQueryItem] = [], headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }

    // If the header has already been set then the value set in the last call to
    // addHeaders will be the value that ends up being used
    public func addHeaders(_ newHeaders: [String: String]) {
        for header in newHeaders {
            self.headers[header.key] = header.value
        }
    }

    public func addQueryItems(_ newQueryItems: [URLQueryItem]) {
        self.queryItems.append(contentsOf: newQueryItems)
    }
}

@objc public class SubscribeRequest: NSObject {

    // TODO: Doesn't seem to be scoped to app - is that desired?
    public var path: String

    public internal(set) var queryItems: [URLQueryItem]
    public internal(set) var headers: [String: String]

    public init(path: String, queryItems: [URLQueryItem] = [], headers: [String: String] = [:]) {
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
    }

    // If the header has already been set then the value set in the last call to
    // addHeaders will be the value that ends up being used
    public func addHeaders(_ newHeaders: [String: String]) {
        for header in newHeaders {
            self.headers[header.key] = header.value
        }
    }

    public func addQueryItems(_ newQueryItems: [URLQueryItem]) {
        self.queryItems.append(contentsOf: newQueryItems)
    }
}
