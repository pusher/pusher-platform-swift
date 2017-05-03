import Foundation

// TODO: Rename to PPURLSessionDelegate?

public class PPSessionDelegate: NSObject {
    public let insecure: Bool
    internal let sessionQueue: DispatchQueue

    public var requests: [Int: PPRequest] = [:]
    private let lock = NSLock()


    open subscript(task: URLSessionTask) -> PPRequest? {
        get {
            lock.lock() ; defer { lock.unlock() }
            return requests[task.taskIdentifier]
        }

        set {
            lock.lock() ; defer { lock.unlock() }
            requests[task.taskIdentifier] = newValue
        }
    }

    public init(insecure: Bool) {
        self.insecure = insecure
        self.sessionQueue = DispatchQueue(label: "com.pusherplatform.swift.ppsessiondelegate.\(NSUUID().uuidString)")
    }

}

extension PPSessionDelegate: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DefaultLogger.Logger.log(message: "Session became invalid: \(session)")
    }

    // TODO: Should potentially be more like request.delegate.handleCompletion(error)
    // I imagine this is called when a data task has finished

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        sessionQueue.async {
            guard let request = self[task] else {
                DefaultLogger.Logger.log(message: "No request found paired with taskIdentifier \(task.taskIdentifier), which errored with error: \(String(describing: error?.localizedDescription))")
                return
            }

            request.delegate.handleCompletion(error: error)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        sessionQueue.async {
            guard let request = self[dataTask] else {
                DefaultLogger.Logger.log(message: "No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received response: \(response)")
                completionHandler(.cancel)
                return
            }

            request.delegate.handle(response, completionHandler: completionHandler)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        sessionQueue.async {
            guard let request = self[dataTask] else {
                DefaultLogger.Logger.log(message: "No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received some data")
                return
            }

            request.delegate.handle(data)
        }
    }

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
