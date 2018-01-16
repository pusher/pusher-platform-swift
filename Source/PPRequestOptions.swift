import Foundation

// TODO: This should probably be a protocol which PPSubscribeRequestOptions
// and PPGeneralRequestOptions conform to

public enum PPDestination: CustomDebugStringConvertible {
    case relative(_: String)
    case absolute(_: String)

    public var debugDescription: String {
        switch self {
        case .relative(let destination), .absolute(let destination):
            return destination
        }
    }
}

public class PPRequestOptions {
    public let method: String
    public var destination: PPDestination
    public internal(set) var queryItems: [URLQueryItem]
    public internal(set) var headers: [String: String]
    public let body: Data?
    public var retryStrategy: PPRetryStrategy?
    public let shouldFetchToken: Bool

    public init(
        method: String,
        destination: PPDestination,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        shouldFetchToken: Bool = true,
        retryStrategy: PPRetryStrategy? = nil
    ) {
        self.method = method
        self.destination = destination
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.shouldFetchToken = shouldFetchToken
        self.retryStrategy = retryStrategy
    }

    public convenience init(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        retryStrategy: PPRetryStrategy? = nil
    ) {
        self.init(
            method: method,
            destination: .relative(path),
            queryItems: queryItems,
            headers: headers,
            body: body,
            retryStrategy: retryStrategy
        )
    }

    // If a header key already exists then calling this will override it
    public func addHeaders(_ newHeaders: [String: String]) {
        for header in newHeaders {
            self.headers[header.key] = header.value
        }
    }

    public func addQueryItems(_ newQueryItems: [URLQueryItem]) {
        self.queryItems.append(contentsOf: newQueryItems)
    }
}

extension PPRequestOptions: CustomDebugStringConvertible {
    public var debugDescription: String {
        let debugString = "\(self.method) request to \(self.destination.debugDescription))"
        let shouldFetchTokenString = "Should fetch token: \(self.shouldFetchToken)"
        var extraInfo = [debugString, shouldFetchTokenString]

        if self.queryItems.count > 0 {
            extraInfo.append("Query items: \(self.queryItems.map { $0.debugDescription }.joined(separator: ", "))")
        }

        if self.headers.count > 0 {
            extraInfo.append("Headers: \(self.headers.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
        }

        if let body = self.body, let bodyString = String(data: body, encoding: .utf8) {
            extraInfo.append("Body: \(bodyString)")
        }

        return extraInfo.joined(separator: "\n")
    }
}

