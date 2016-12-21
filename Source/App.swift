import Foundation

// TODO: Move this somewhere sensible
@objc public class AppRequest: NSObject {
    public let method: String
    public let path: String
    public let queryItems: [URLQueryItem]?
    public let jwt: String?
    public let headers: [String: String]?
    public let body: Data?

    public init(method: String, path: String, queryItems: [URLQueryItem]? = nil, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.jwt = jwt
        self.headers = headers
        self.body = body
    }
}


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

    public func request(using appRequest: AppRequest, completionHandler: @escaping (Result<Data>) -> Void) -> Void {
        let sanitisedPath = sanitise(path: appRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        if appRequest.jwt == nil && self.authorizer != nil {
            self.authorizer!.authorize { result in
                switch result {
                case .failure(let error): completionHandler(.failure(error))
                case .success(let jwtFromAuthorizer):
                    // TODO: Stop having to create the AppRequest in two places when they're so similar

                    let baseClientRequest = AppRequest(
                        method: appRequest.method,
                        path: namespacedPath,
                        queryItems: appRequest.queryItems,
                        jwt: jwtFromAuthorizer,
                        headers: appRequest.headers,
                        body: appRequest.body
                    )

                    self.client.request(using: baseClientRequest, completionHandler: completionHandler)
                }
            }
        } else {
            let baseClientRequest = AppRequest(
                method: appRequest.method,
                path: namespacedPath,
                queryItems: appRequest.queryItems,
                jwt: appRequest.jwt,
                headers: appRequest.headers,
                body: appRequest.body
            )

            self.client.request(using: baseClientRequest, completionHandler: completionHandler)
        }
    }

    // TODO: Should this be -> Subscription? or maybe always return a Subscription, or Result<Subscription>
    public func subscribe(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        jwt: String? = nil,
        headers: [String: String]? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        completionHandler: @escaping (Result<Subscription>) -> Void) -> Void {
            let sanitisedPath = sanitise(path: path)
            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

            if jwt == nil && self.authorizer != nil {
                self.authorizer!.authorize { result in
                    switch result {
                    case .failure(let error): completionHandler(.failure(error))
                    case .success(let jwtFromAuthorizer):
                        self.client.subscribe(
                            path: namespacedPath,
                            queryItems: queryItems,
                            jwt: jwtFromAuthorizer,
                            headers: headers,
                            onOpen: onOpen,
                            onEvent: onEvent,
                            onEnd: onEnd,
                            onError: onError,
                            completionHandler: completionHandler
                        )
                    }
                }
            } else {
                let subscription = self.client.subscribe(
                    path: namespacedPath,
                    queryItems: queryItems,
                    jwt: jwt,
                    headers: headers,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd,
                    onError: onError,
                    completionHandler: completionHandler
                )
            }
    }
//
//    public func subscribeWithResume(
//        path: String,
//        queryItems: [URLQueryItem]? = nil,
//        jwt: String? = nil,
//        headers: [String: String]? = nil,
//        onOpen: (() -> Void)? = nil,
//        onEvent: ((String, [String: String], Any) -> Void)? = nil,
//        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
//        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
//        onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = nil) throws -> Promise<ResumableSubscription> {
//            let sanitisedPath = sanitise(path: path)
//            let namespacedPath = namespace(path: sanitisedPath, appId: self.id)
//
//            if jwt == nil && self.authorizer != nil {
//                return self.authorizer!.authorize().then { jwtFromAuthorizer in
//                    return self.client.subscribeWithResume(
//                        app: self,
//                        path: namespacedPath,
//                        queryItems: queryItems,
//                        jwt: jwtFromAuthorizer,
//                        headers: headers,
//                        onOpen: onOpen,
//                        onEvent: onEvent,
//                        onEnd: onEnd,
//                        onStateChange: onStateChange,
//                        onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
//                    )
//                }
//            } else {
//                return self.client.subscribeWithResume(
//                    app: self,
//                    path: namespacedPath,
//                    queryItems: queryItems,
//                    jwt: jwt,
//                    headers: headers,
//                    onOpen: onOpen,
//                    onEvent: onEvent,
//                    onEnd: onEnd,
//                    onStateChange: onStateChange,
//                    onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
//                )
//            }
//    }

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
