//
//  BaseClient.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

import PromiseKit

let VERSION = "0.1.0"
let CLIENT_NAME = "elements-client-swift"
let REALLY_LONG_TIME: Double = 252_460_800

@objc public class BaseClient: NSObject {
    public var jwt: String?
    public var baseUrl: URL
    public var port: Int?

    public let subscriptionUrlSession: Foundation.URLSession
    public let subscriptionManager: SubscriptionManager

    public init(jwt: String? = nil, cluster: String? = nil, port: Int? = nil) throws {
        self.jwt = jwt

        // TODO: Put in a sensible default
        let cluster = cluster ?? "sensible.default"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if port != nil {
            urlComponents.port = port!
        }

        guard let url = urlComponents.url else {
            throw BaseClientError.invalidBaseUrl(components: urlComponents)
        }

        self.baseUrl = url

        self.subscriptionManager = SubscriptionManager()

        let subscriptionSessionDelegate = SubscriptionSessionDelegate(subscriptionManager:  subscriptionManager)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscriptionUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscriptionSessionDelegate, delegateQueue: nil)
    }

    public func request(method: HttpMethod, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        return request(method: method.rawValue, path: path, jwt: jwt, headers: headers, body: body)
    }

    public func request(method: String, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        let url = self.baseUrl.appendingPathComponent(path)

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
        return Promise<Data> { fulfill, reject in
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

                let dataString = String(data: data, encoding: String.Encoding.utf8)

                guard let httpResponse = response as? HTTPURLResponse else {
                    // TODO: Print dataString somewhere sensible
                    print(dataString!)
                    reject(RequestError.invalidHttpResponse(data: data))
                    return
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    // TODO: Print dataString somewhere sensible
                    print(dataString!)
                    reject(RequestError.badResponseStatusCode(response: httpResponse, data: data))
                    return
                }

                fulfill(data)
            }).resume()
        }
    }

    public func subscribe(path: String, jwt: String? = nil, headers: [String: String]? = nil) -> Promise<Subscription> {
        let url = self.baseUrl.appendingPathComponent(path)

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

        return Promise<Subscription> { fulfill, reject in
            guard self.subscriptionManager.subscriptions[taskIdentifier] == nil else {
                reject(BaseClientError.preExistingTaskIdentifierForSubscription)
                return
            }

            let subscription = Subscription(path: path, taskIdentifier: taskIdentifier)
            self.subscriptionManager.subscriptions[taskIdentifier] = (subscription, Resolvers(promiseFulfiller: fulfill, promiseRejector: reject))
            task.resume()
        }
    }
}

public class SubscriptionSessionDelegate: SessionDelegate, URLSessionDataDelegate {
    public let subscriptionManager: SubscriptionManager

    public init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
    }

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // TODO: Do something proper with this eror
        print("Error, invalid session")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // TODO: Do something proper with this eror
        print("Error with URLSessionTask: \(error?.localizedDescription)")
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.subscriptionManager.handle(task: dataTask, response: response, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // TODO: probably need to make things clearer if no subscription is found that matches the taskIdentifier of the dataTask
        self.subscriptionManager.subscriptions[dataTask.taskIdentifier]?.subscription.onEvent?(data)
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
    case invalidBaseUrl(components: URLComponents)
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
