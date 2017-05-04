import Foundation

// TODO: This should probably be a protocol which PPSubscribeRequestOptions
// and PPGeneralRequestOptions conform to

public class PPRequestOptions {
    public let method: String

    // TODO: Doesn't seem to be scoped to app - is that desired?

    public var path: String

    public internal(set) var queryItems: [URLQueryItem]
    public internal(set) var headers: [String: String]
    public let body: Data?
    public var retryStrategy: PPRetryStrategy?

    public init(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        retryStrategy: PPRetryStrategy? = nil
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.retryStrategy = retryStrategy
    }

    public func addHeaders(_ newHeaders: [String: String]) {
        for header in newHeaders {
            self.headers[header.key] = header.value
        }
    }

    public func addQueryItems(_ newQueryItems: [URLQueryItem]) {
        self.queryItems.append(contentsOf: newQueryItems)
    }
}
