//
//  ElementsApp.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import PromiseKit
import PMKFoundation

@objc public class ElementsApp: NSObject {
    public var appId: String
    public var cluster: String?
    public var authorizer: Authorizer?
    public var client: BaseClient

    public init(appId: String, cluster: String? = nil, authorizer: Authorizer? = nil, client: BaseClient? = nil) throws {
        self.appId = appId
        self.cluster = cluster
        self.authorizer = authorizer
        try self.client = client ?? BaseClient(cluster: cluster)
    }

    public func request(method: String, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        let sanitisedPath = sanitisePath(path: path)
        let namespacedPath = "/apps/\(self.appId)\(sanitisedPath)"

        if jwt == nil && self.authorizer != nil {
            return self.authorizer!.authorize().then { jwtFromAuthorizer in
                return self.client.request(method: method, path: path, jwt: jwtFromAuthorizer, headers: headers, body: body)
            }
        } else {
            return self.client.request(method: method, path: namespacedPath, jwt: jwt, headers: headers, body: body)
        }
    }

    public func subscribe(path: String, jwt: String? = nil, headers: [String: String]? = nil) throws -> Promise<Subscription> {
        let sanitisedPath = sanitisePath(path: path)
        let namespacedPath = "/apps/\(self.appId)\(sanitisedPath)"

        if jwt == nil && self.authorizer != nil {
            return self.authorizer!.authorize().then { jwtFromAuthorizer in
                return self.client.subscribe(path: namespacedPath, jwt: jwtFromAuthorizer, headers: headers)
            }
        } else {
            return self.client.subscribe(path: namespacedPath, jwt: jwt, headers: headers)
        }
    }

    // TODO: put this somewhere sensible
    internal func sanitisePath(path: String) -> String {
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
}

@objc public class ElementsError: NSObject {
    public let code: Int
    public let reason: String

    public init(code: Int, reason: String) {
        self.code = code
        self.reason = reason
    }
}
