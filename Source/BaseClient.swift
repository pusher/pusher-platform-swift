//
//  BaseClient.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 05/10/2016.
//
//

let VERSION = "0.1.0"
let CLIENT_NAME = "elements-client-swift"
let REALLY_LONG_TIME: Double = 252_460_800


// TODO: don't think we want this anymore
public class ConnectionManager {
    public init() {

    }
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

    public func request(method: HttpMethod, path: String, data: Data? = nil) {
        request(method: method.rawValue, path: path, data: data)
    }

    public func request(method: String, path: String, data: Data? = nil) {
        let url = self.baseUrl.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = REALLY_LONG_TIME
        if self.jwt != nil {
            request.addValue("JWT \(self.jwt!)", forHTTPHeaderField: "Authorization")
        }

        if data != nil {
            request.httpBody = data
        }

        var task: URLSessionDataTask

        if method == "SUB" {
            task = self.subscribeUrlSession.dataTask(with: request)
        } else {
            task = self.generalUrlSession.dataTask(with: request)
        }
        
        task.resume()
    }

    // TODO: probs remove this
    // public func get(path: String) {
    //     self.request(method: HttpMethod.GET, path: path)
    // }

    // public func subscribe(path: String) {
    //     self.request(method: HttpMethod.SUB, path: path)
    // }

    // public func post(path: String, data: Data? = nil) {
    //     self.request(method: HttpMethod.POST, path: path, data: data)
    // }

    // public func put(path: String, data: Data? = nil) {
    //     self.request(method: HttpMethod.PUT, path: path, data: data)
    // }

    // public func patch(path: String, data: Data? = nil) {
    //     self.request(method: HttpMethod.PATCH, path: path, data: data)
    // }

    // public func delete(path: String) {
    //     self.request(method: HttpMethod.DELETE, path: path)
    // }

    // public func head(path: String) {
    //     self.request(method: HttpMethod.HEAD, path: path)
    // }
    
    // public func options(path: String) {
    //     self.request(method: HttpMethod.OPTIONS, path: path)
    // }
}

public class GeneralSessionDelegate: SessionDelegate, URLSessionDelegate, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("Task \(dataTask.taskIdentifier) received a response: \(response)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("Task \(task.taskIdentifier) completed with an error: \(error)")
    }

}

public class SubscribeSessionDelegate: SessionDelegate, URLSessionDelegate, URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let dataString = String(data: data, encoding: .utf8)
        print("Received this: \(dataString!)")
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
    case SUB
    case POST
    case GET
    case PUT
    case DELETE
    case OPTIONS
    case PATCH
    case HEAD
}
