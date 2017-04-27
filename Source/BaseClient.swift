import Foundation

let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var port: Int?
    internal var baseUrlComponents: URLComponents
    public let subscriptionUrlSession: URLSession
    public let subscriptionSessionDelegate: SubscriptionSessionDelegate

    // Should be between 30 and 300
    public let heartbeatTimeout: Int

    // Should be between 0 and 10240 (to avoid 422 response) but URLSession
    // seems to need 512+ bytes to ensure that it calls didReceiveResponse
    public let heartbeatInitialSize: Int

    // Set to true if you want to trust all certificates
    public let insecure: Bool

    // TODO: Need to actually use these
    public var clientName: String
    public var clientVersion: String

    public init(
        cluster: String? = nil,
        port: Int? = nil,
        insecure: Bool = false,
        clientName: String = "pusher-platform-swift",
        clientVersion: String = "0.1.4",
        heartbeatTimeoutInterval: Int = 60,
        heartbeatInitialSize: Int = 512
    ) {
        let cluster = cluster ?? "api.private-beta-1.pusherplatform.com"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster
        urlComponents.port = port

        self.baseUrlComponents = urlComponents
        self.insecure = insecure
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.heartbeatTimeout = heartbeatTimeoutInterval
        self.heartbeatInitialSize = heartbeatInitialSize

        let subscriptionSessionConfiguration = URLSessionConfiguration.default
        subscriptionSessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        subscriptionSessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME
        subscriptionSessionConfiguration.httpAdditionalHeaders = [
            "X-Heartbeat-Interval": String(self.heartbeatTimeout),
            "X-Initial-Heartbeat-Size": String(self.heartbeatInitialSize)
        ]

        self.subscriptionSessionDelegate = SubscriptionSessionDelegate(insecure: insecure)
        self.subscriptionUrlSession = URLSession(
            configuration: subscriptionSessionConfiguration,
            delegate: subscriptionSessionDelegate,
            delegateQueue: nil
        )
    }

    deinit {
        self.subscriptionUrlSession.invalidateAndCancel()
    }

    public func request(using generalRequest: GeneralRequest, completionHandler: @escaping (Result<Data>) -> Void) -> Void {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = generalRequest.queryItems

        guard var url = mutableURLComponents.url else {
            completionHandler(.failure(BaseClientError.invalidUrl(components: mutableURLComponents)))
            return
        }

        url = url.appendingPathComponent(generalRequest.path)

        var request = URLRequest(url: url)
        request.httpMethod = generalRequest.method

        for (header, value) in generalRequest.headers {
            request.addValue(value, forHTTPHeaderField: header)
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

                // TODO: This error should be provided a proper error message if possible -
                // check how this works with block based requests as opposed to delegate
                // pattern

                completionHandler(.failure(RequestError.badResponseStatusCode(response: httpResponse)))
                return
            }

            completionHandler(.success(data))
        }).resume()
    }

    // TODO Some useful TODOs down below

    public func subscribe(
        with subscription: inout Subscription,
        using subscribeRequest: SubscribeRequest,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = subscribeRequest.queryItems

        guard var url = mutableURLComponents.url else {
            // TODO: Maybe defer calling onError until after returning?

            onError?(BaseClientError.invalidUrl(components: mutableURLComponents))
            return
        }

        url = url.appendingPathComponent(subscribeRequest.path)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.SUBSCRIBE.rawValue
        request.timeoutInterval = REALLY_LONG_TIME

        for (header, value) in subscribeRequest.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)

        guard self.subscriptionSessionDelegate[task] == nil else {
            onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
            return
        }

        self.subscriptionSessionDelegate[task] = subscription

        subscription.delegate.task = task
        subscription.delegate.heartbeatTimeout = Double(self.heartbeatTimeout)
        subscription.delegate.onOpening = onOpening
        subscription.delegate.onOpen = onOpen
        subscription.delegate.onEvent = onEvent
        subscription.delegate.onEnd = onEnd
        subscription.delegate.onError = onError

        task.resume()
    }

    public func subscribeWithResume(
        with resumableSubscription: inout ResumableSubscription,
        using subscribeRequest: SubscribeRequest,
        app: App,
        onOpening: (() -> Void)? = nil,
        onOpen: (() -> Void)? = nil,
        onResuming: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil
    ) {
        var mutableURLComponents = self.baseUrlComponents
        mutableURLComponents.queryItems = subscribeRequest.queryItems

        guard var url = mutableURLComponents.url else {
            onError?(BaseClientError.invalidUrl(components: mutableURLComponents))
            return
        }

        url = url.appendingPathComponent(subscribeRequest.path)

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.SUBSCRIBE.rawValue
        request.timeoutInterval = REALLY_LONG_TIME

        for (header, value) in subscribeRequest.headers {
            request.addValue(value, forHTTPHeaderField: header)
        }

        let task: URLSessionDataTask = self.subscriptionUrlSession.dataTask(with: request)

        guard self.subscriptionSessionDelegate[task] == nil else {
            onError?(BaseClientError.preExistingTaskIdentifierForSubscription)
            return
        }

        let subscription = Subscription()
        self.subscriptionSessionDelegate[task] = subscription
        subscription.delegate.task = task
        subscription.delegate.heartbeatTimeout = Double(self.heartbeatTimeout)

        resumableSubscription.subscription = subscription

        resumableSubscription.onOpening = onOpening
        resumableSubscription.onOpen = onOpen
        resumableSubscription.onResuming = onResuming
        resumableSubscription.onEvent = onEvent
        resumableSubscription.onEnd = onEnd
        resumableSubscription.onError = onError

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

// TODO: Dry up repetition with subscription delegate

extension BaseClient: URLSessionDelegate {

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
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
    case badResponseStatusCode(response: HTTPURLResponse)
    case badResponseStatusCodeWithMessage(response: HTTPURLResponse, errorMessage: String)
    case noDataPresent
}

public enum SubscriptionError: Error {
    case unexpectedError
    case heartbeatTimeoutReached
}

public enum HTTPMethod: String {
    case POST
    case GET
    case PUT
    case DELETE
    case OPTIONS
    case PATCH
    case HEAD
    case SUBSCRIBE
}
