import PromiseKit

let VERSION = "0.1.0"
let CLIENT_NAME = "elements-client-swift"
let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var jwt: String?
    public var port: Int?
    internal var baseUrlComponents: URLComponents

    public let subscriptionUrlSession: Foundation.URLSession
    public let subscriptionManager: SubscriptionManager

    public init(jwt: String? = nil, cluster: String? = nil, port: Int? = nil) throws {
        self.jwt = jwt

        let cluster = cluster ?? "beta.buildelements.com"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if port != nil {
            urlComponents.port = port!
        }

        self.baseUrlComponents = urlComponents

        self.subscriptionManager = SubscriptionManager()

        let subscriptionSessionDelegate = SubscriptionSessionDelegate(subscriptionManager:  subscriptionManager)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscriptionUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscriptionSessionDelegate, delegateQueue: nil)
    }

    public func request(method: HttpMethod, path: String, queryItems: [URLQueryItem]? = nil, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        return request(method: method.rawValue, path: path, queryItems: queryItems, jwt: jwt, headers: headers, body: body)
    }

    public func request(method: String, path: String, queryItems: [URLQueryItem]? = nil, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        self.baseUrlComponents.queryItems = queryItems

        return Promise<Data> { fulfill, reject in

            guard var url = self.baseUrlComponents.url else {
                reject(BaseClientError.invalidUrl(components: self.baseUrlComponents))
                return
            }

            url = url.appendingPathComponent(path)

            var request = URLRequest(url: url)
            request.httpMethod = method

            // TODO: Not sure we want this timeout to be so long for non-subscribe requests
            request.timeoutInterval = REALLY_LONG_TIME

            if jwt != nil {
                request.addValue("JWT \(jwt!)", forHTTPHeaderField: "Authorization")
            }

            if headers != nil {
                for (header, value) in headers! {
                    request.addValue(value, forHTTPHeaderField: header)
                }
            }

            if body != nil {
                request.httpBody = body
            }

            // TODO: Figure out a sensible URLSessionConfiguration setup to use here
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
            sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

            let sessionDelegate = SessionDelegate()

            let session = URLSession(
                configuration: sessionConfiguration,
                delegate: sessionDelegate,
                delegateQueue: nil
            )

            session.dataTask(with: request, completionHandler: { data, response, sessionError in
                if let error = sessionError {
                    reject(error)
                    return
                }

                guard let data = data else {
                    reject(RequestError.noDataPresent)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    // TODO: Print dataString somewhere sensible
                    let dataString = String(data: data, encoding: String.Encoding.utf8)
                    print(dataString!)
                    reject(RequestError.invalidHttpResponse(data: data))
                    return
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    // TODO: Print dataString somewhere sensible
                    let dataString = String(data: data, encoding: String.Encoding.utf8)
                    print(dataString!)
                    reject(RequestError.badResponseStatusCode(response: httpResponse, data: data))
                    return
                }

                fulfill(data)
            }).resume()
        }
    }

    /**

    */
    public func subscribe(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        jwt: String? = nil,
        headers: [String: String]? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil) -> Promise<Subscription> {
            self.baseUrlComponents.queryItems = queryItems

            return Promise<Subscription> { fulfill, reject in
                guard var url = self.baseUrlComponents.url else {
                    reject(BaseClientError.invalidUrl(components: self.baseUrlComponents))
                    return
                }

                url = url.appendingPathComponent(path)

                var request = URLRequest(url: url)
                request.httpMethod = "SUBSCRIBE"
                request.timeoutInterval = REALLY_LONG_TIME

                if jwt != nil {
                    request.addValue("JWT \(jwt!)", forHTTPHeaderField: "Authorization")
                }

                if headers != nil {
                    for (header, value) in headers! {
                        request.addValue(value, forHTTPHeaderField: header)
                    }
                }

                let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)
                let taskIdentifier = task.taskIdentifier

                guard self.subscriptionManager.subscriptions[taskIdentifier] == nil else {
                    reject(BaseClientError.preExistingTaskIdentifierForSubscription)
                    return
                }

                let subscription = Subscription(
                    path: path,
                    taskIdentifier: taskIdentifier,
                    onOpen: onOpen,
                    onEvent: onEvent,
                    onEnd: onEnd
                )

                self.subscriptionManager.subscriptions[taskIdentifier] = (subscription, Resolvers(promiseFulfiller: fulfill, promiseRejector: reject))
                task.resume()
            }
    }

    public func subscribeWithResume(
        app: ElementsApp,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        jwt: String? = nil,
        headers: [String: String]? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = nil) -> Promise<ResumableSubscription> {
            self.baseUrlComponents.queryItems = queryItems

            let resumableSubscription = ResumableSubscription(
                app: app,
                path: path,
                jwt: nil,
                headers: headers,
                onStateChange: onStateChange,
                // TODO: maybe by specifying this here we don't need the unwrap and then immediate
                // rewrap at the bottom of this func?
                onUnderlyingSubscriptionChange: onUnderlyingSubscriptionChange
            )

            return Promise<Subscription> { subscriptionPromiseFulfill, subscriptionPromiseReject in
                guard var url = self.baseUrlComponents.url else {
                    subscriptionPromiseReject(BaseClientError.invalidUrl(components: self.baseUrlComponents))
                    return
                }

                url = url.appendingPathComponent(path)

                var request = URLRequest(url: url)
                request.httpMethod = "SUBSCRIBE"
                request.timeoutInterval = REALLY_LONG_TIME

                if jwt != nil {
                    request.addValue("JWT \(jwt!)", forHTTPHeaderField: "Authorization")
                }

                if headers != nil {
                    for (header, value) in headers! {
                        request.addValue(value, forHTTPHeaderField: header)
                    }
                }

                let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)
                let taskIdentifier = task.taskIdentifier

                guard self.subscriptionManager.subscriptions[taskIdentifier] == nil else {
                    subscriptionPromiseReject(BaseClientError.preExistingTaskIdentifierForSubscription)
                    return
                }

                let subscription = Subscription(
                    path: path,
                    taskIdentifier: taskIdentifier
                )

                // TODO: No no no there must be a better way
                resumableSubscription.subscription = subscription
                resumableSubscription.onOpen = onOpen
                resumableSubscription.onEvent = onEvent
                resumableSubscription.onEnd = onEnd

                self.subscriptionManager.subscriptions[taskIdentifier] = (subscription, Resolvers(promiseFulfiller: subscriptionPromiseFulfill, promiseRejector: subscriptionPromiseReject))

                task.resume()
            }.then { subscription in
                return Promise<ResumableSubscription> { fulfill, reject in
                    resumableSubscription.subscription = subscription

                    fulfill(resumableSubscription)
                }
            }
    }

    public func unsubscribe(taskIdentifier: Int) {
        self.subscriptionUrlSession.getAllTasks { tasks in
            for task in tasks {
                if task.taskIdentifier == taskIdentifier {
                    // TODO: check why we can't cancel without cancelling all tasks in the session
                    task.suspend()
                }
            }
        }
    }
}

public class SubscriptionSessionDelegate: SessionDelegate, URLSessionDataDelegate {
    public let subscriptionManager: SubscriptionManager

    public init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // TODO: Don't think we should ever really see this error - find out what can cause it
        print("Error, invalid session")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // TODO: Maybe add some debug logging
        self.subscriptionManager.handleError(taskIdentifier: task.taskIdentifier, error: error)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.subscriptionManager.handle(taskIdentifier: dataTask.taskIdentifier, response: response, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            let messages = try MessageParser.parse(data: data)
            self.subscriptionManager.handle(messages: messages, taskIdentifier: dataTask.taskIdentifier)
        } catch let error as MessageParseError {
            print(error.localizedDescription)
        } catch {
            print("Unable to parse message received over subscription")
        }
    }

}

@objc public class SessionDelegate: NSObject, URLSessionDelegate {

    // TODO: Remove this when all TLS stuff is sorted out properly
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.previousFailureCount == 0 else {
            challenge.sender?.cancel(challenge)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let allowAllCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, allowAllCredential)
    }
}

public enum BaseClientError: Error {
    case invalidUrl(components: URLComponents)
    case preExistingTaskIdentifierForSubscription
}

public enum RequestError: Error {
    case badResponseStatusCode(response: HTTPURLResponse, data: Data)
    case invalidHttpResponse(data: Data?)
    case noDataPresent
}

public enum HttpMethod: String {
    case POST
    case GET
    case PUT
    case DELETE
    case OPTIONS
    case PATCH
    case HEAD
}
