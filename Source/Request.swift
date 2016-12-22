import Foundation

@objc public class GeneralRequest: NSObject {
    public let method: String
    public var path: String
    public let queryItems: [URLQueryItem]?
    public let headers: [String: String]?
    public let body: Data?
    public var jwt: String?

    public init(method: String, path: String, queryItems: [URLQueryItem]? = nil, headers: [String: String]? = nil, body: Data? = nil, jwt: String? = nil) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.jwt = jwt
        self.headers = headers
        self.body = body
    }
}

@objc public class SubscribeRequest: NSObject {
    public var path: String
    public let queryItems: [URLQueryItem]?
    public let headers: [String: String]?
    public var jwt: String?

    public init(path: String, queryItems: [URLQueryItem]? = nil, headers: [String: String]? = nil, jwt: String? = nil) {
        self.path = path
        self.queryItems = queryItems
        self.jwt = jwt
        self.headers = headers
    }
}
