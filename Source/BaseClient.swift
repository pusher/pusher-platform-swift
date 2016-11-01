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

    public let subscribeUrlSession: Foundation.URLSession
    public let generalUrlSession: Foundation.URLSession

    public let connectionManager: ConnectionManager

    // TODO: Should this be able to throw? 
    public init(jwt: String? = nil, cluster: String? = nil, port: Int? = nil) throws {
        self.jwt = jwt

        // TODO: Use a sensible default
        let cluster = cluster ?? "sensible.default"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if port != nil {
            urlComponents.port = port!
        }

        guard let url = urlComponents.url else {
            // TODO: sort out proper error logging / handling (reason: "Invalid Url constructed from comonents: \(cluster), \(port)")
            throw BaseClientError.invalidBaseUrl
        }

        self.baseUrl = url

        self.connectionManager = ConnectionManager()

        let generalSessionDelegate = GeneralSessionDelegate(connectionManager: connectionManager)
        let subscribeSessionDelegate = SubscribeSessionDelegate(connectionManager:  connectionManager)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME


        // TODO: probs get rid of this / specify what it really should be
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        self.subscribeUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscribeSessionDelegate, delegateQueue: nil)
        self.generalUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: generalSessionDelegate, delegateQueue: nil)


        // TODO: probs don't need this anymore
        super.init()
    }

    public func request(method: HttpMethod, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        return request(method: method.rawValue, path: path, jwt: jwt, headers: headers, body: body)
    }

    public func request(method: String, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> Promise<Data> {
        let url = self.baseUrl.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method

        // TODO: Not sure we ant this timeout to be so long in general
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

        // TODO: don't need to use general url session here I don't think
        // can probably just use a shared one (with appropriate timeouts and background behaviours etc set)

        return Promise<Data> { fulfill, reject in
            self.generalUrlSession.dataTask(with: request, completionHandler: { data, response, sessionError in
                if let error = sessionError {
                    reject(error)
                    return
                }

                guard let data = data else {
                    reject(RequestError.noDataPresent)
                    return
                }

                let dataString = String(data: data, encoding: String.Encoding.utf8)

                guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                    // TODO: Print dataString somewhere sensible
                    print(dataString!)
                    reject(RequestError.invalidHttpResponse)
                    return
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    // TODO: Print dataString somewhere sensible
                    print(dataString!)
                    reject(RequestError.badResponseStatusCode)
                    return
                }
                
                fulfill(data)
            }).resume()
        }
    }

    // TODO: Remove when we're using SUBSCRIBE everywhere as HTTP method for subs
    public func sub(path: String, jwt: String? = nil, headers: [String: String]? = nil) -> Promise<Subscription> {
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



        // TODO: Check that the ordering of things makes sense here - e.g. do we want to resume before or after
        // creating the subscription in the connection manager? when do we create the promise?




        let task: URLSessionDataTask = self.subscribeUrlSession.dataTask(with: request)

        let taskIdentifier = task.taskIdentifier

        let subscription = Subscription(path: path, taskIdentifier: taskIdentifier)

        // TODO: Check that there doesn't exist any subscription with same taskIdentifier
        self.connectionManager.subscriptions[taskIdentifier] = subscription

        task.resume()

        print("———————————————")
        print(self.subscribeUrlSession.delegate)



        // TODO: does this make sense?
        return Promise<Subscription> { fulfill, reject in
            fulfill(subscription)
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

        // TODO: Check that the ordering of things makes sense here - e.g. do we want to resume before or after
        // creating the subscription in the connection manager? when do we create the promise?

        let task: URLSessionDataTask = self.subscribeUrlSession.dataTask(with: request)

        let taskIdentifier = task.taskIdentifier
        let subscription = Subscription(path: path, taskIdentifier: taskIdentifier)

//        TODO: Check that there doesn't exist any subscription with same taskIdentifier
        self.connectionManager.subscriptions[taskIdentifier] = subscription

        task.resume()

//        TODO: does this make sense?
        return Promise<Subscription> { fulfill, reject in
            fulfill(subscription)
        }
    }
}

public class GeneralSessionDelegate: SessionDelegate, URLSessionDelegate, URLSessionDataDelegate {

    // TODO: I think we can remove the general session delegate entirely
    // which means in fact that we can go back to a single delegate - YAY

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("Task \(dataTask.taskIdentifier) received a response: \(response)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Task \(task.taskIdentifier) completed with an error: \(error)")
    }

}

public class SubscribeSessionDelegate: SessionDelegate, URLSessionDelegate, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("%%%%%%%%%%%%%%%%%%%%%%%%")
        print(response)
        print("%%%%%%%%%%%%%%%%%%%%%%%%")

        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("**************************** DATA RECEIVED ************************************")
        print(data)

        // TODO: make this use the correct subscription object to call any onEvent closure
        // TODO: probably need to make things clearer if no subscription is found that matches the taskIdentifier of the dataTask
        self.connectionManager.subscriptions[dataTask.taskIdentifier]?.onEvent?(data)
    }

}

@objc public class SessionDelegate: NSObject {
    public let connectionManager: ConnectionManager

    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }

    // TODO: Remove this when all TLS stuff is sorted out properly
    // TODO: Check what's going on with the @objc thing here
    @objc(URLSession:didReceiveChallenge:completionHandler:) public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("Fucker's gonna get challenged")

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
    case invalidBaseUrl
}

public enum RequestError: Error {
    case badResponseStatusCode
    case invalidHttpResponse
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
