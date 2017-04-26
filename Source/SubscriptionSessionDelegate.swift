import Foundation

public class SubscriptionSessionDelegate: NSObject {
    public var subscriptions: [Int: Subscription] = [:]
    internal let subscriptionSessionQueue: DispatchQueue

    private let lock = NSLock()

    open subscript(task: URLSessionTask) -> Subscription? {
        get {
            lock.lock() ; defer { lock.unlock() }
            return subscriptions[task.taskIdentifier]
        }

        set {
            lock.lock() ; defer { lock.unlock() }
            subscriptions[task.taskIdentifier] = newValue
        }
    }

    public let insecure: Bool

    public init(insecure: Bool) {
        self.insecure = insecure
        self.subscriptionSessionQueue = DispatchQueue(label: "com.pusherplatform.swift.subscriptionsessiondelegate.\(NSUUID().uuidString)")
    }
}

extension SubscriptionSessionDelegate: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DefaultLogger.Logger.log(message: "Session became invalid: \(session)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        subscriptionSessionQueue.async {
            guard let subscription = self[task] else {
                DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(task.taskIdentifier), which errored with error: \(String(describing: error?.localizedDescription))")
                return
            }

            subscription.delegate.handle(error)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        subscriptionSessionQueue.async {
            guard let subscription = self[dataTask] else {
                DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(dataTask.taskIdentifier), which received response: \(response)")
                completionHandler(.cancel)
                return
            }

            subscription.delegate.handle(response, completionHandler: completionHandler)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        subscriptionSessionQueue.async {
            guard let subscription = self[dataTask] else {
                DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(dataTask.taskIdentifier), which received some data")
                return
            }

            subscription.delegate.handle(data)
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
