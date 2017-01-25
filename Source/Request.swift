import Foundation

@objc public class GeneralRequest: NSObject {
    public let method: String
    public var path: String
    public let queryItems: [URLQueryItem]?
    public let headers: [String: String]?
    public let body: Data?

    public init(method: String, path: String, queryItems: [URLQueryItem]? = nil, headers: [String: String]? = nil, body: Data? = nil) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}

@objc public class SubscribeRequest: NSObject {
    // TODO: Doesn't seem to be scoped to app - is that desired? 
    public var path: String
    public let queryItems: [URLQueryItem]?
    public var headers: [String: String]?

    public init(path: String, queryItems: [URLQueryItem]? = nil, headers: [String: String]? = nil) {
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
    }
}
