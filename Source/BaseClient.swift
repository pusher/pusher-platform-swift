import Foundation

let VERSION = "0.1.3"
let CLIENT_NAME = "pusher-platform-swift"
let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var port: Int?
    internal var baseUrlComponents: URLComponents

    public let subscriptionUrlSession: Foundation.URLSession
    public let subscriptionSessionDelegate: SubscriptionSessionDelegate

    public let insecure: Bool

    public init(cluster: String? = nil, port: Int? = nil, insecure: Bool = false) {
        let cluster = cluster ?? "api.private-beta-1.pusherplatform.com"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if let port = port {
            urlComponents.port = port
        }

        self.baseUrlComponents = urlComponents
        self.insecure = insecure

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscriptionSessionDelegate = SubscriptionSessionDelegate(insecure: insecure)
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

        if let headers = generalRequest.headers {
            for (header, value) in headers {
                request.addValue(value, forHTTPHeaderField: header)
            }
        }

        if let body = generalRequest.body {
            request.httpBody = body
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)

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
                // TODO: Why can't I access the data in the error I get returned?
                // Should the logger be called with the data as a string, if possible?
                completionHandler(.failure(RequestError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            completionHandler(.success(data))
        }).resume()
    }

    public func subscribe(
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil) -> Subscription {
            let subscription = Subscription(
                path: subscribeRequest.path,
                onOpening: onOpening,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )

            self.baseUrlComponents.queryItems = subscribeRequest.queryItems

            guard var url = self.baseUrlComponents.url else {
                onError?(BaseClientError.invalidUrl(components: self.baseUrlComponents))
                return subscription
            }

            url = url.appendingPathComponent(subscribeRequest.path)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.SUBSCRIBE.rawValue
            request.timeoutInterval = REALLY_LONG_TIME

            if let headers = subscribeRequest.headers {
                for (header, value) in headers {
                    request.addValue(value, forHTTPHeaderField: header)
                }
            }

            let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)
            let taskIdentifier = task.taskIdentifier

            guard self.subscriptionSessionDelegate.subscriptions[taskIdentifier] == nil else {
                onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
                return subscription
            }

            subscription.taskIdentifier = taskIdentifier
            self.subscriptionSessionDelegate.subscriptions[taskIdentifier] = subscription

            task.resume()

            return subscription
    }

    public func subscribeWithResume(
        resumableSubscription: inout ResumableSubscription,
        using subscribeRequest: SubscribeRequest,
        app: App,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil) {
            self.baseUrlComponents.queryItems = subscribeRequest.queryItems

            guard var url = self.baseUrlComponents.url else {
                onError?(BaseClientError.invalidUrl(components: self.baseUrlComponents))
                return
            }

            url = url.appendingPathComponent(subscribeRequest.path)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.SUBSCRIBE.rawValue
            request.timeoutInterval = REALLY_LONG_TIME

            if let headers = subscribeRequest.headers {
                for (header, value) in headers {
                    request.addValue(value, forHTTPHeaderField: header)
                }
            }

            let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)
            let taskIdentifier = task.taskIdentifier


            // TODO: This dopesn't seem threadsafe
            guard self.subscriptionSessionDelegate.subscriptions[taskIdentifier] == nil else {
                onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
                return
            }

            let subscription = Subscription(
                path: subscribeRequest.path,
                taskIdentifier: taskIdentifier
            )

            // TODO: No no no there must be a better way
            resumableSubscription.subscription = subscription

            resumableSubscription.onOpening = onOpening
            resumableSubscription.onOpen = onOpen
            resumableSubscription.onResuming = onResuming
            resumableSubscription.onEvent = onEvent
            resumableSubscription.onEnd = onEnd
            resumableSubscription.onError = onError

            self.subscriptionSessionDelegate.subscriptions[taskIdentifier] = subscription

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

// TODO: Check this is legit and dry up repetition with subscription delegate

extension BaseClient: URLSessionDelegate {

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.previousFailureCount == 0 else {
            challenge.sender?.cancel(challenge)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if self.insecure {
            let allowAllCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, allowAllCredential)
        } else {
            completionHandler(.performDefaultHandling, nil)
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

public enum SubscriptionError: Error {
    case unexpectedError
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
}
