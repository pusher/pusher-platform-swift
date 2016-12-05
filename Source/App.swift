import PromiseKit

@objc public class App: NSObject {
    public var id: String
    public var cluster: String?
    public var authorizer: Authorizer?
    public var client: BaseClient

    public init(id: String, cluster: String? = nil, authorizer: Authorizer? = nil, client: BaseClient? = nil) throws {
        self.id = id
        self.cluster = cluster
        self.authorizer = authorizer
        try self.client = client ?? BaseClient(cluster: cluster)
    }

    public func request(method: String, path: String, queryItems: [URLQueryItem]? = nil, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        let sanitisedPath = sanitise(path: path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        if jwt == nil && self.authorizer != nil {
            return self.authorizer!.authorize().then { jwtFromAuthorizer in
                return self.client.request(
                    method: method,
                    path: namespacedPath,
                    queryItems: queryItems,
                    jwt: jwtFromAuthorizer,
                    headers: headers,
                    body: body
                )
            }
        } else {
            return self.client.request(
                method: method,
                path: namespacedPath,
                queryItems: queryItems,
                jwt: jwt,
                headers: headers,
                body: body
            )
        }
    }

    public func subscribe(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        jwt: String? = nil,
        headers: [String: String]? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil) throws -> Promise<Subscription> {
            let sanitisedPath = sanitise(path: path)
            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

            if jwt == nil && self.authorizer != nil {
                return self.authorizer!.authorize().then { jwtFromAuthorizer in
                    return self.client.subscribe(
                        path: namespacedPath,
                        queryItems: queryItems,
                        jwt: jwtFromAuthorizer,
                        headers: headers,
                        onOpen: onOpen,
                        onEvent: onEvent,
                        onEnd: onEnd
                    )
                }
            } else {
                return self.client.subscribe(
                    path: namespacedPath,
                    jwt: jwt,
                    headers: headers,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd
                )
            }
    }

    public func subscribeWithResume(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        jwt: String? = nil,
        headers: [String: String]? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = nil) throws -> Promise<ResumableSubscription> {
            let sanitisedPath = sanitise(path: path)
            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

            if jwt == nil && self.authorizer != nil {
                return self.authorizer!.authorize().then { jwtFromAuthorizer in
                    return self.client.subscribeWithResume(
                        app: self,
                        path: namespacedPath,
                        queryItems: queryItems,
                        jwt: jwtFromAuthorizer,
                        headers: headers,
                        onOpen: onOpen,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onStateChange: onStateChange,
                        onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
                    )
                }
            } else {
                return self.client.subscribeWithResume(
                    app: self,
                    path: namespacedPath,
                    queryItems: queryItems,
                    jwt: jwt,
                    headers: headers,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onStateChange: onStateChange,
                    onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
                )
            }
    }

    public func unsubscribe(taskIdentifier: Int) {
        self.client.unsubscribe(taskIdentifier: taskIdentifier)
    }

    internal func sanitise(path: String) -> String {
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

    // Only prefix with /apps/APP_ID if /apps/ isn't at the start of the path
    internal func namespace(path: String, appId: String) -> String {
        let endIndex = path.index(path.startIndex, offsetBy: 6)

        if path.substring(to: endIndex) == "/apps/" {
            return path
        } else {
            let namespacedPath = "/apps/\(appId)\(path)"
            return namespacedPath
        }
    }
}
