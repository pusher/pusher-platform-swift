//
//  ElementsApp.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import PromiseKit

@objc public class Subscription: NSObject {
    public var path: String
    public var taskIdentifier: Int
    public var onOpen: (() -> Void)? = nil
    public var onEnd: ((Int, String) -> Void)? = nil
    public var onEvent: ((Data) -> Void)? = nil

    public init(path: String, taskIdentifier: Int) {
        self.path = path
        self.taskIdentifier = taskIdentifier
    }
}

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

    public func request(method: String, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> URLDataPromise {
        let sanitisedPath = sanitisePath(path: path)
        let namespacedPath = "/apps/\(self.appId)\(sanitisedPath)"

        // TODO: Chain promises here for authorizer in case of HTTP request
        let jwtToUse = jwt ?? self.jwt ?? self.authorizer?.authorize().jwt ?? nil

        return self.client.request(method: method, path: namespacedPath, jwt: jwtToUse, headers: headers, body: body)
    }

    public func subscribe(path: String, jwt: String? = nil, headers: [String: String]? = nil) -> Subscription {
        let sanitisedPath = sanitisePath(path: path)
        let namespacedPath = "/apps/\(self.appId)\(sanitisedPath)"

        // TODO: Chain promises here for authorizer in case of HTTP request
        let jwtToUse = jwt ?? self.jwt ?? self.authorizer?.authorize().jwt ?? nil

        return self.client.subscribe(path: namespacedPath, jwt: jwtToUse, headers: headers)
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



// TODO: I think we can remove these
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
