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


// TODO: not sure if this is the best abstaction - do we even want a separate "manager" object?
@objc public class ConnectionManager: NSObject {
    public var subscriptions: [Subscription] = []

    // public init() {}
}

public enum BaseClientError: Error {
    case invalidBaseUrl
}

@objc public class BaseClient: NSObject {
    public var jwt: String?
    public var baseUrl: URL
    public var port: Int?

    public let subscribeUrlSession: Foundation.URLSession
    public let generalUrlSession: Foundation.URLSession

    public let connectionManager: ConnectionManager


    public init(jwt: String? = nil, cluster: String? = nil, port: Int? = nil) throws {
        self.jwt = jwt

        let cluster = cluster ?? "sensible.default"

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = cluster

        if port != nil {
            urlComponents.port = port!
        }

        guard let url = urlComponents.url else {
            throw BaseClientError.invalidBaseUrl // TODO: sort out proper error logging / handling (reason: "Invalid Url constructed from comonents: \(cluster), \(port)")
        }

        self.baseUrl = url

        self.connectionManager = ConnectionManager()

        let generalSessionDelegate = GeneralSessionDelegate(connectionManager: connectionManager)
        let subscribeSessionDelegate = SubscribeSessionDelegate(connectionManager:  connectionManager)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscribeUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscribeSessionDelegate, delegateQueue: nil)
        self.generalUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: generalSessionDelegate, delegateQueue: nil)

        super.init()
    }

    public func request(method: HttpMethod, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> URLDataPromise {
        return request(method: method.rawValue, path: path, jwt: jwt, headers: headers, body: body)
    }

    public func request(method: String, path: String, jwt: String? = nil, headers: [String: String]? = nil, body: Data? = nil) -> URLDataPromise {
        let url = self.baseUrl.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
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

        return self.generalUrlSession.dataTask(with: request)
    }

    public func subscribe(path: String, jwt: String? = nil, headers: [String: String]? = nil) -> Subscription {
        let url = self.baseUrl.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = "SUB"
        request.timeoutInterval = REALLY_LONG_TIME

        if jwt != nil {
            request.addValue("JWT \(jwt!)", forHTTPHeaderField: "Authorization")
        }

        if headers != nil {
            for (header, value) in headers! {
                request.addValue(value, forHTTPHeaderField: header)
            }
        }

        let task: URLSessionDataTask = self.subscribeUrlSession.dataTask(with: request)
        task.resume()
        let subscription = Subscription(path: path, taskIdentifier: task.taskIdentifier)
        self.connectionManager.subscriptions.append(subscription)

        return subscription
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

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // TODO: make this use the correct subscription object to call any onEvent closure
        self.connectionManager.subscriptions.first?.onEvent?(data)
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
        guard challenge.previousFailureCount == 0 else {
            challenge.sender?.cancel(challenge)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let allowAllCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, allowAllCredential)
    }
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
