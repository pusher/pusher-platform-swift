import Foundation

let VERSION = "0.1.0"
let CLIENT_NAME = "elements-client-swift"
let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var port: Int?
    internal var baseUrlComponents: URLComponents

    public let subscriptionUrlSession: Foundation.URLSession
    public let subscriptionSessionDelegate: SubscriptionSessionDelegate

    public init(cluster: String? = nil, port: Int? = nil) throws {
        let cluster = cluster ?? "beta.buildelements.com"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if let port = port {
            urlComponents.port = port
        }

        self.baseUrlComponents = urlComponents

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscriptionSessionDelegate = SubscriptionSessionDelegate()
        self.subscriptionUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscriptionSessionDelegate, delegateQueue: nil)
    }

    public func request(using generalRequest: GeneralRequest, completionHandler: @escaping (Result<Data>) -> Void) -> Void {
        self.baseUrlComponents.queryItems = generalRequest.queryItems

        guard var url = self.baseUrlComponents.url else {
            completionHandler(.failure(BaseClientError.invalidUrl(components: self.baseUrlComponents)))
            return
        }

        url = url.appendingPathComponent(generalRequest.path)

        var request = URLRequest(url: url)
        request.httpMethod = generalRequest.method

        if let jwt = generalRequest.jwt {
            request.addValue("JWT \(jwt)", forHTTPHeaderField: "Authorization")
        }

        if let headers = generalRequest.headers {
            for (header, value) in headers {
                request.addValue(value, forHTTPHeaderField: header)
            }
        }

        if let body = generalRequest.body {
            request.httpBody = body
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: sessionConfiguration)

        session.dataTask(with: request, completionHandler: { data, response, sessionError in
            if let error = sessionError {
                completionHandler(.failure(error))
                return
            }

            guard let data = data else {
                completionHandler(.failure(RequestError.noDataPresent))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(RequestError.invalidHttpResponse(response: response, data: data)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completionHandler(.failure(RequestError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            completionHandler(.success(data))
        }).resume()
    }

    public func subscribe(
        using subscribeRequest: SubscribeRequest,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        internalOnEventHandlers: [(String, [String: String], Any) -> Void] = [],
        completionHandler: (Result<Subscription>) -> Void) -> Void {
            self.baseUrlComponents.queryItems = subscribeRequest.queryItems

            guard var url = self.baseUrlComponents.url else {
                completionHandler(.failure(BaseClientError.invalidUrl(components: self.baseUrlComponents)))
                return
            }

            url = url.appendingPathComponent(subscribeRequest.path)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.SUBSCRIBE.rawValue
            request.timeoutInterval = REALLY_LONG_TIME

            if let jwt = subscribeRequest.jwt {
                request.addValue("JWT \(jwt)", forHTTPHeaderField: "Authorization")
            }

            if let headers = subscribeRequest.headers {
                for (header, value) in headers {
                    request.addValue(value, forHTTPHeaderField: header)
                }
            }

            let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)
            let taskIdentifier = task.taskIdentifier

            guard self.subscriptionSessionDelegate.subscriptions[taskIdentifier] == nil else {
                completionHandler(.failure(BaseClientError.preExistingTaskIdentifierForSubscription))
                return
            }

            let subscription = Subscription(
                path: subscribeRequest.path,
                taskIdentifier: taskIdentifier,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError,
                internalOnEventHandlers: internalOnEventHandlers
            )

            self.subscriptionSessionDelegate.subscriptions[taskIdentifier] = subscription
            completionHandler(.success(subscription))

            task.resume()
    }

    public func subscribeWithResume(
        using subscribeRequest: SubscribeRequest,
        app: App,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        internalOnEventHandlers: [(String, [String: String], Any) -> Void] = [],
        completionHandler: (Result<ResumableSubscription>) -> Void) -> Void {
            self.baseUrlComponents.queryItems = subscribeRequest.queryItems

            let resumableSubscription = ResumableSubscription(
                app: app,
                path: subscribeRequest.path,
                onStateChange: onStateChange
            )

            guard var url = self.baseUrlComponents.url else {
                completionHandler(.failure(BaseClientError.invalidUrl(components: self.baseUrlComponents)))
                return
            }

            url = url.appendingPathComponent(subscribeRequest.path)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.SUBSCRIBE.rawValue
            request.timeoutInterval = REALLY_LONG_TIME

            if let jwt = subscribeRequest.jwt {
                request.addValue("JWT \(jwt)", forHTTPHeaderField: "Authorization")
            }

            if let headers = subscribeRequest.headers {
                for (header, value) in headers {
                    request.addValue(value, forHTTPHeaderField: header)
                }
            }

            let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)
            let taskIdentifier = task.taskIdentifier

            // TODO: This dopesn't seem threadsafe
            guard self.subscriptionSessionDelegate.subscriptions[taskIdentifier] == nil else {
                completionHandler(.failure(BaseClientError.preExistingTaskIdentifierForSubscription))
                return
            }

            let subscription = Subscription(
                path: subscribeRequest.path,
                taskIdentifier: taskIdentifier,
                internalOnEventHandlers: internalOnEventHandlers
            )

            // TODO: No no no there must be a better way
            resumableSubscription.subscription = subscription
            resumableSubscription.onOpen = onOpen
            resumableSubscription.onEvent = onEvent
            resumableSubscription.onEnd = onEnd
            resumableSubscription.onError = onError

            self.subscriptionSessionDelegate.subscriptions[taskIdentifier] = subscription
            completionHandler(.success(resumableSubscription))

            task.resume()
    }

    public func unsubscribe(taskIdentifier: Int, completionHandler: ((Result<Bool>) -> Void)? = nil) -> Void {
        self.subscriptionUrlSession.getAllTasks { tasks in
            guard tasks.count > 0 else {
                completionHandler?(.failure(BaseClientError.noTasksForSubscriptionUrlSession(self.subscriptionUrlSession)))
                return
            }

            let filteredTasks = tasks.filter { $0.taskIdentifier == taskIdentifier }

            guard filteredTasks.count == 1 else {
                completionHandler?(.failure(BaseClientError.noTaskWithMatchingTaskIdentifierFound(taskId: taskIdentifier, session: self.subscriptionUrlSession)))
                return
            }

            filteredTasks.first!.cancel()
            completionHandler?(.success(true))
        }
    }
}

public enum BaseClientError: Error {
    case invalidUrl(components: URLComponents)
    case preExistingTaskIdentifierForSubscription
    case noTasksForSubscriptionUrlSession(URLSession)
    case noTaskWithMatchingTaskIdentifierFound(taskId: Int, session: URLSession)
}

public enum RequestError: Error {
    case invalidHttpResponse(response: URLResponse?, data: Data?)
    case badResponseStatusCode(response: HTTPURLResponse, data: Data?)
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
    case SUBSCRIBE
    case APPEND
}
