//
//  PusherSwift.swift
//
//  Created by Hamilton Chapman on 19/02/2015.
//
//

import Foundation

let VERSION = "0.1.0"
let CLIENT_NAME = "elements-swift" // TODO: check for proper naming
let REALLY_LONG_TIME: Double = 252_460_800

// TODO: use this class for sensible things
public class ConnectionManager {
    public init() {

    }
}

@objc public class ElementsClient: NSObject {
    public var baseUrl: URL? = nil
    public let config: ElementsClientConfig
    public let connectionManager: ConnectionManager
    public let subscribeUrlSession: Foundation.URLSession
    public let generalUrlSession: Foundation.URLSession

    public init(config: ElementsClientConfig) {
        self.config = config
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = config.host

        if config.port != nil {
            urlComponents.port = config.port
        }

        urlComponents.path = config.namespace.stringValue

        self.baseUrl = urlComponents.url
        self.connectionManager = ConnectionManager()

        let generalSessionDelegate = ElementsGeneralSessionDelegate(connectionManager: connectionManager)
        let subscribeSessionDelegate = ElementsSubscribeSessionDelegate(connectionManager:  connectionManager)

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForResource = REALLY_LONG_TIME
        sessionConfiguration.timeoutIntervalForRequest = REALLY_LONG_TIME

        self.subscribeUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: subscribeSessionDelegate, delegateQueue: nil)
        self.generalUrlSession = Foundation.URLSession(configuration: sessionConfiguration, delegate: generalSessionDelegate, delegateQueue: nil)

        super.init()
    }

    public func request(method: HttpMethod, path: String, data: Data? = nil) {
        guard let url = self.baseUrl?.appendingPathComponent(path) else {
            print("Invalid url")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = REALLY_LONG_TIME
        request.addValue("JWT \(self.config.token)", forHTTPHeaderField: "Authorization")

        if data != nil {
            request.httpBody = data
        }

        var task: URLSessionDataTask

        if method == .SUB {
            task = self.subscribeUrlSession.dataTask(with: request)
        } else {
            task = self.generalUrlSession.dataTask(with: request)
        }

        task.resume()
    }

    public func get(path: String) {
        self.request(method: HttpMethod.GET, path: path)
    }

    public func subscribe(path: String) {
        self.request(method: HttpMethod.SUB, path: path)
    }

    public func post(path: String, data: Data? = nil) {
        self.request(method: HttpMethod.POST, path: path, data: data)
    }

    public func put(path: String, data: Data? = nil) {
        self.request(method: HttpMethod.PUT, path: path, data: data)
    }

    public func patch(path: String, data: Data? = nil) {
        self.request(method: HttpMethod.PATCH, path: path, data: data)
    }

    public func delete(path: String) {
        self.request(method: HttpMethod.DELETE, path: path)
    }

    public func head(path: String) {
        self.request(method: HttpMethod.HEAD, path: path)
    }

    public func options(path: String) {
        self.request(method: HttpMethod.OPTIONS, path: path)
    }
}


class ElementsGeneralSessionDelegate: ElementsSessionDelegate, URLSessionDelegate, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("Task \(dataTask.taskIdentifier) received a response: \(response)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Task \(task.taskIdentifier) completed with an error: \(error?.localizedDescription)")
    }

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

public class ElementsSubscribeSessionDelegate: ElementsSessionDelegate, URLSessionDelegate, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let dataString = String(data: data, encoding: .utf8)
        print("Received this: \(dataString!)")
    }

    // TODO: check if can place in parent class to be shared
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

public class ElementsSessionDelegate: NSObject {
    public let connectionManager: ConnectionManager

    public init(connectionManager: ConnectionManager) {
        self.connectionManager = connectionManager
    }
}

@objc public class ElementsClientConfig: NSObject {
    public let token: String
    public let host: String
    public let namespace: ElementsNamespace
    public let port: Int?

    public init(token: String, host: String = "api.elements.io", namespace: ElementsNamespace, port: Int? = nil) {
        self.token = token
        self.host = host
        self.namespace = namespace
        self.port = port
    }
}

public enum ElementsNamespace {
    case appId(String)
    case raw(String)

    public var stringValue: String {
        switch self {
            case .appId(let appId): return "/apps/\(appId)"
            case .raw(let raw): return raw
        }
    }
}

public enum HttpMethod: String {
    case SUB
    case POST
    case GET
    case PUT
    case DELETE
    case OPTIONS
    case PATCH
    case HEAD
}

