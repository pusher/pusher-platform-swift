import Foundation

@objc public class App: NSObject {
    public var id: String
    public var cluster: String?
    public var authorizer: Authorizer?
    public var client: BaseClient

    public init(id: String, cluster: String? = nil, authorizer: Authorizer? = nil, client: BaseClient? = nil) {
        self.id = id
        self.cluster = cluster
        self.authorizer = authorizer
        self.client = client ?? BaseClient(cluster: cluster)
    }

    public func request(using generalRequest: GeneralRequest, completionHandler: @escaping (Result<Data>) -> Void) -> Void {
        let sanitisedPath = sanitise(path: generalRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = generalRequest
        mutableBaseClientRequest.path = namespacedPath

        if self.authorizer != nil {
            self.authorizer!.authorize { result in
                switch result {
                case .failure(let error): completionHandler(.failure(error))
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])
                    self.client.request(using: mutableBaseClientRequest, completionHandler: completionHandler)
                }
            }
        } else {
            self.client.request(using: mutableBaseClientRequest, completionHandler: completionHandler)
        }
    }

    public func subscribe(
        with subscription: inout Subscription,
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let sanitisedPath = sanitise(path: subscribeRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = subscribeRequest
        mutableBaseClientRequest.path = namespacedPath

        if self.authorizer != nil {
            // TODO: The weak here feels dangerous

            self.authorizer!.authorize { [weak subscription] result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribe(
                        with: &subscription!,
                        using: mutableBaseClientRequest,
                        onOpening: onOpening,
                        onOpen: onOpen,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.subscribe(
                with: &subscription,
                using: mutableBaseClientRequest,
                onOpening: onOpening,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }
    }

    public func subscribeWithResume(
        with resumableSubscription: inout ResumableSubscription,
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        let sanitisedPath = sanitise(path: subscribeRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = subscribeRequest
        mutableBaseClientRequest.path = namespacedPath

        if self.authorizer != nil {
            self.authorizer!.authorize { [weak resumableSubscription] result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribeWithResume(
                        with: &resumableSubscription!,
                        using: mutableBaseClientRequest,
                        app: self,
                        onOpening: onOpening,
                        onOpen: onOpen,
                        onResuming: onResuming,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.subscribeWithResume(
                with: &resumableSubscription,
                using: mutableBaseClientRequest,
                app: self,
                onOpening: onOpening,
                onOpen: onOpen,
                onResuming: onResuming,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }
    }

    public func subscribe(
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> Subscription {
        let sanitisedPath = sanitise(path: subscribeRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = subscribeRequest
        mutableBaseClientRequest.path = namespacedPath

        // TODO: Maybe Subscription should take the whole request object?

        var subscription = Subscription()

        if self.authorizer != nil {
            self.authorizer!.authorize { result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribe(
                        with: &subscription,
                        using: mutableBaseClientRequest,
                        onOpening: onOpening,
                        onOpen: onOpen,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.subscribe(
                with: &subscription,
                using: mutableBaseClientRequest,
                onOpening: onOpening,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }

        return subscription
    }

    public func subscribeWithResume(
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) -> ResumableSubscription {
        let sanitisedPath = sanitise(path: subscribeRequest.path)
        let namespacedPath = namespace(path: sanitisedPath, appId: self.id)

        let mutableBaseClientRequest = subscribeRequest
        mutableBaseClientRequest.path = namespacedPath

        var resumableSubscription = ResumableSubscription(app: self, request: subscribeRequest)

        if self.authorizer != nil {
            // TODO: Does resumableSubscription need to be weak here?

            self.authorizer!.authorize { [weak resumableSubscription] result in
                switch result {
                case .failure(let error): onError?(error)
                case .success(let jwtFromAuthorizer):
                    let authHeaderValue = "Bearer \(jwtFromAuthorizer)"
                    mutableBaseClientRequest.addHeaders(["Authorization": authHeaderValue])

                    self.client.subscribeWithResume(
                        with: &resumableSubscription!,
                        using: mutableBaseClientRequest,
                        app: self,
                        onOpening: onOpening,
                        onOpen: onOpen,
                        onResuming: onResuming,
                        onEvent: onEvent,
                        onEnd: onEnd,
                        onError: onError
                    )
                }
            }
        } else {
            self.client.subscribeWithResume(
                with: &resumableSubscription,
                using: mutableBaseClientRequest,
                app: self,
                onOpening: onOpening,
                onOpen: onOpen,
                onResuming: onResuming,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )
        }

        return resumableSubscription
    }

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Result<Bool>) -> Void)? = nil) {
        self.client.unsubscribe(taskIdentifier: taskIdentifier, completionHandler: completionHandler)
    }

    internal func sanitise(path: String) -> String {
        var sanitisedPath = ""

        for char in path.characters {
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
