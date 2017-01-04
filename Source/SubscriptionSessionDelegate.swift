import Foundation

public class SubscriptionSessionDelegate: NSObject, URLSessionDataDelegate {
    public var subscriptions: [Int: Subscription] = [:]

    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DefaultLogger.Logger.log(message: "Session became invalid: \(session)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
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
            DefaultLogger.Logger.log(message: "Error parsing messages received for task with id \(dataTask.taskIdentifier): \(error.localizedDescription)")
        } catch let error {
            DefaultLogger.Logger.log(message: "Error parsing messages received for task with id \(dataTask.taskIdentifier): \(error.localizedDescription)")
        }
    }


    // MARK: subscription event handlers

    internal func handle(taskIdentifier: Int, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        defer {
            completionHandler(.allow)
        }

        guard let subscription = self.subscriptions[taskIdentifier] else {
            DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(taskIdentifier)")
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            subscription.onError?(RequestError.invalidHttpResponse(response: response, data: nil))
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            subscription.onOpen?()
        } else {
            subscription.onError?(RequestError.badResponseStatusCode(response: httpResponse, data: nil))
        }
    }

    internal func handle(messages: [Message], taskIdentifier: Int) {
        guard let subscription = self.subscriptions[taskIdentifier] else {
            DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(taskIdentifier)")
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
            DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(taskIdentifier)")
            return
        }

        subscription.onEnd?(nil, nil, error)
    }
}
