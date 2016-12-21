import Foundation

let VERSION = "0.1.0"
let CLIENT_NAME = "elements-client-swift"
let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var port: Int?
    internal var baseUrlComponents: URLComponents

    public let subscriptionUrlSession: Foundation.URLSession

    // TODO: We might not want to keep a reference to this and instead just access it 
    // through subscriptionUrlSession.delegate
    public let subscriptionSessionDelegate: SubscriptionSessionDelegate

    public init(cluster: String? = nil, port: Int? = nil) throws {
        let cluster = cluster ?? "beta.buildelements.com"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if port != nil {
            urlComponents.port = port!
        }

        self.baseUrlComponents = urlComponents

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscriptionSessionDelegate = SubscriptionSessionDelegate()
        self.subscriptionUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscriptionSessionDelegate, delegateQueue: nil)
    }

    // TODO: Fix this to work with AppRequest setup
//    public func request(method: HttpMethod, path: String, queryItems: [URLQueryItem]? = nil, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
//        return request(method: method.rawValue, path: path, queryItems: queryItems, jwt: jwt, headers: headers, body: body)
//    }


    public func request(using appRequest: AppRequest, completionHandler: @escaping (Result<Data>) -> Void) -> Void {
        self.baseUrlComponents.queryItems = appRequest.queryItems

        guard var url = self.baseUrlComponents.url else {
            completionHandler(.failure(BaseClientError.invalidUrl(components: self.baseUrlComponents)))
            return
        }

        url = url.appendingPathComponent(appRequest.path)

        var request = URLRequest(url: url)
        request.httpMethod = appRequest.method

        // TODO: Not sure we want this timeout to be so long for non-subscribe requests
        request.timeoutInterval = REALLY_LONG_TIME

        if appRequest.jwt != nil {
            request.addValue("JWT \(appRequest.jwt!)", forHTTPHeaderField: "Authorization")
        }

        if appRequest.headers != nil {
            for (header, value) in appRequest.headers! {
                request.addValue(value, forHTTPHeaderField: header)
            }
        }

        if appRequest.body != nil {
            request.httpBody = appRequest.body!
        }

        // TODO: Figure out a sensible URLSessionConfiguration setup to use here
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME


        // TODO: Decide whether a delegate is required
//        let sessionDelegate = SessionDelegate()

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
                // TODO: Print dataString somewhere sensible
                let dataString = String(data: data, encoding: String.Encoding.utf8)
                print(dataString!)
                completionHandler(.failure(RequestError.invalidHttpResponse(data: data)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                // TODO: Print dataString somewhere sensible
                let dataString = String(data: data, encoding: String.Encoding.utf8)
                print(dataString!)
                completionHandler(.failure(RequestError.badResponseStatusCode(response: httpResponse, data: data)))
                return
            }

            completionHandler(.success(data))
        }).resume()
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
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        completionHandler: (Result<Subscription>) -> Void) -> Void {
            self.baseUrlComponents.queryItems = queryItems

            guard var url = self.baseUrlComponents.url else {
                completionHandler(.failure(BaseClientError.invalidUrl(components: self.baseUrlComponents)))
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

            guard self.subscriptionSessionDelegate.subscriptions[taskIdentifier] == nil else {
                completionHandler(.failure(BaseClientError.preExistingTaskIdentifierForSubscription))
                return
            }

            let subscription = Subscription(
                path: path,
                taskIdentifier: taskIdentifier,
                onOpen: onOpen,
                onEvent: onEvent,
                onEnd: onEnd,
                onError: onError
            )

            // TODO: Should we call success before setting the subscription in the session delegate?
            completionHandler(.success(subscription))

            self.subscriptionSessionDelegate.subscriptions[taskIdentifier] = subscription

            task.resume()
    }

    public func subscribeWithResume(
        app: App,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        jwt: String? = nil,
        headers: [String: String]? = nil,
        onOpen: (() -> Void)? = nil,
        onEvent: ((String, [String: String], Any) -> Void)? = nil,
        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
        onError: ((Error) -> Void)? = nil,
        onStateChange: ((ResumableSubscriptionState, ResumableSubscriptionState) -> Void)? = nil,
        onUnderlyingSubscriptionChange: ((Subscription?, Subscription?) -> Void)? = nil,
        completionHandler: (Result<ResumableSubscription>) -> Void) -> Void {
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

            guard var url = self.baseUrlComponents.url else {
                completionHandler(.failure(BaseClientError.invalidUrl(components: self.baseUrlComponents)))
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

            // TODO: This dopesn't seem threadsafe
            guard self.subscriptionSessionDelegate.subscriptions[taskIdentifier] == nil else {
                completionHandler(.failure(BaseClientError.preExistingTaskIdentifierForSubscription))
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
            resumableSubscription.onError = onError

            self.subscriptionSessionDelegate.subscriptions[taskIdentifier] = subscription

            completionHandler(.success(resumableSubscription))

            task.resume()
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
