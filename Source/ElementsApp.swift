//
//  ElementsApp.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

@objc public class ElementsApp: NSObject {
    public var appId: String
    public var jwt: String?
    public var cluster: String?
    public var authorizer: Authorizer?
    public var client: BaseClient

    public init(appId: String, jwt: String? = nil, cluster: String? = nil, authorizer: Authorizer? = nil, client: BaseClient? = nil) throws {
        self.appId = appId
        self.jwt = jwt
        self.cluster = cluster
        self.authorizer = authorizer
        try self.client = client ?? BaseClient(cluster: cluster)
    }

    public func request(options: RequestOptions) {
        
    }

    public func subscribe(options: SubscribeOptions) {

    }
}

// TODO: put these somewhere sensible
public func sanitiseNamespace(namespace: String) -> String {
    return sanitisePath(path: namespace)
}

public func sanitisePath(path: String) -> String {
    var sanitisedPath = ""

    for (_, char) in path.characters.enumerated() {
        // only append a slash if last character isn't already a slash
        if char == "/" {
            if !sanitisedPath.hasSuffix("/") {
                sanitisedPath.append(char)
            }
        } else {
            sanitisedPath.append(char)
        }
    }

    // remove trailing slash
    if sanitisedPath.hasSuffix("/") {
        sanitisedPath.remove(at: sanitisedPath.index(before: sanitisedPath.endIndex))
    }

    // ensure leading slash
    if !sanitisedPath.hasPrefix("/") {
        sanitisedPath = "/\(sanitisedPath)"
    }

    return sanitisedPath
}

@objc public class RequestOptions: NSObject {
    public var method: String
    public var path: String
    public var jwt: String?
    public var headers: [String: String]?
    public var body: Data?

    public init(method: String, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) {
        self.method = method
        self.path = path
        self.jwt = jwt
        self.headers = headers
        self.body = body
    }
}

@objc public class SubscribeOptions: NSObject {
    public var path: String
    public var jwt: String?
    public var headers: [String: String]?

    public init(path: String, jwt: String? = nil, headers: [String: String]? = nil) {
        self.path = path
        self.jwt = jwt
        self.headers = headers
    }
}

@objc public class ElementsError: NSObject {
    public let code: Int
    public let reason: String

    public init(code: Int, reason: String) {
        self.code = code
        self.reason = reason
    }
}
