import Foundation


// TODO: URLSessionTaskDelegate

public class SubscriptionSessionDelegate: NSObject, URLSessionDataDelegate {
    public var subscriptions: [Int: Subscription] = [:]

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        // TODO: Don't think we should ever really see this error - find out what can cause it
        print("Error, invalid session")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // TODO: Maybe add some debug logging
        handleError(taskIdentifier: task.taskIdentifier, error: error)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        handle(taskIdentifier: dataTask.taskIdentifier, response: response, completionHandler: completionHandler)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            let messages = try MessageParser.parse(data: data)
            handle(messages: messages, taskIdentifier: dataTask.taskIdentifier)
        } catch let error as MessageParseError {
            print(error.localizedDescription)
        } catch {
            print("Unable to parse message received over subscription")
        }
    }


    // MARK: subscription event handlers

    internal func handle(taskIdentifier: Int, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        defer {
            completionHandler(.allow)
        }

        guard let subscription = self.subscriptions[taskIdentifier] else {
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            subscription.onOpen?()
        } else {
            subscription.onError?(RequestError.invalidHttpResponse(data: nil))
        }
    }

    internal func handle(messages: [Message], taskIdentifier: Int) {
        guard let subscription = self.subscriptions[taskIdentifier] else {
            print("No subscription found paired with taskIdentifier \(taskIdentifier)")
            return
        }

        for message in messages {
            switch message {
            case Message.keepAlive:
                break
            case Message.event(let eventId, let headers, let body):
                subscription.onEvent?(eventId, headers, body)
            case Message.eos(let statusCode, let headers, let info):
                subscription.onEnd?(statusCode, headers, info)
            }
        }
    }

    internal func handleError(taskIdentifier: Int, error: Error?) {
        guard let subscription = subscriptions[taskIdentifier] else {
            return
        }

        // TODO: Do we want localizedDescription or just the error?
        subscription.onEnd?(nil, nil, error)
    }


    // MARK: TLS auth challenge

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
