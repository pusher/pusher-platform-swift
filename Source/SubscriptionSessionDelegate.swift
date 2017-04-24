import Foundation

public class SubscriptionSessionDelegate: NSObject, URLSessionDataDelegate {
    public var subscriptions: [Int: Subscription] = [:]
    internal let subscriptionQueue: DispatchQueue

    public let insecure: Bool

    public init(insecure: Bool) {
        self.insecure = insecure
        self.subscriptionQueue = DispatchQueue(label: "com.pusherplatform.swift.subscriptiondelegate.\(NSUUID().uuidString)")
    }

    // TODO: Each subscription should probably have its own delegate to avoid having
    // to do things like this
    public var tempDataStore: [Int: Data] = [:]

    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DefaultLogger.Logger.log(message: "Session became invalid: \(session)")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        subscriptionQueue.async {
            self.handleError(taskIdentifier: task.taskIdentifier, error: error)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        subscriptionQueue.async {
            self.handle(taskIdentifier: dataTask.taskIdentifier, response: response, completionHandler: completionHandler)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        subscriptionQueue.async {
            let taskIdentifier = dataTask.taskIdentifier

            guard let subscription = self.subscriptions[taskIdentifier] else {
                DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(taskIdentifier), which received some data")
                return
            }

            // TODO: This is designed to capture more context about an error that occurs
            // in conjunction with a unacceptable status code. It needs to be made more
            // robust though.

            guard subscription.badResponseCodeError == nil else {
                let error = subscription.badResponseCodeError!

                switch error {
                case .badResponseStatusCode(var responseDataTuple):

                    // TODO: Make all of this proper

                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                        DefaultLogger.Logger.log(message: "Not legit JSON")
                        return
                    }

                    guard let errorDict = jsonObject as? [String: String] else {
                        DefaultLogger.Logger.log(message: "Error stuff not a dict of strings")
                        return
                    }

                    guard let errorDescription = errorDict["error_description"] else {
                        DefaultLogger.Logger.log(message: "No error description")
                        return
                    }

                    print(errorDescription)

                    // TODO: This is a shortcut for now, more useful to make it human-readable, surely

                    responseDataTuple.data = data
                default:
                    // TODO: Decide what to do here, probs just let it go and ignore
                    print("NAH")
                }

                return
            }

            if self.tempDataStore[taskIdentifier] != nil {
                self.tempDataStore[taskIdentifier]!.append(data)
            }

            let dataToParse = self.tempDataStore[taskIdentifier] ?? data

            guard let dataString = String(data: dataToParse, encoding: .utf8) else {
                DefaultLogger.Logger.log(message: "Failed to convert received Data to String for task id \(dataTask.taskIdentifier)")
                return
            }

            let stringMessages = dataString.components(separatedBy: "\n")

            // No newline character in data received so the received data should be stored, ready
            // for the next data to be received
            guard stringMessages.count > 1 else {
                var mutableData = self.tempDataStore[taskIdentifier]

                if mutableData != nil {
                    mutableData!.append(data)
                    self.tempDataStore[taskIdentifier] = mutableData!
                } else {
                    self.tempDataStore[taskIdentifier] = data
                }
                return
            }

            do {
                let messages = try MessageParser.parse(stringMessages: stringMessages)
                self.handle(messages: messages, subscription: subscription)
                self.tempDataStore.removeValue(forKey: taskIdentifier)
            } catch let error {
                DefaultLogger.Logger.log(message: "Error parsing messages received for task id \(dataTask.taskIdentifier): \(error.localizedDescription)")
            }
        }
    }


    // MARK: subscription event handlers

    internal func handle(taskIdentifier: Int, response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let subscription = self.subscriptions[taskIdentifier] else {
            DefaultLogger.Logger.log(message: "No subscription found paired with taskIdentifier \(taskIdentifier)")
            completionHandler(.cancel)
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            subscription.onError?(RequestError.invalidHttpResponse(response: response, data: nil))

            // TODO: Should this be cancel?

            completionHandler(.cancel)
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            subscription.onOpen?()
        } else {
            let badResponseCodeError = RequestError.badResponseStatusCode(response: httpResponse, data: nil)

            // TODO: Should we call onError now - what if data is received that can be
            // used to augment the error? Maybe set a timeout and send the error plain
            // if no data is received within the timeout

            subscription.onError?(badResponseCodeError)
            subscription.badResponseCodeError = badResponseCodeError
        }

        // TODO: Should we cancel here if there's an error because of the status code?

        completionHandler(.allow)
    }

    internal func handle(messages: [Message], subscription: Subscription) {
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

        // TODO: Where do we check if an error has already been communicated? How do we
        // determine whether an error is one that should be communicated immediately or
        // if it should be one that is held until some extra data is received to augment
        // the error returned to the client

        guard subscription.error == nil else {
            DefaultLogger.Logger.log(message: "Subscription to \(subscription.path) has already communicated an error: \(String(describing: subscription.error?.localizedDescription))")
            return
        }

        guard error != nil else {
            subscription.onError?(SubscriptionError.unexpectedError)
            return
        }

        // TOOD: Maybe check if error!.localizedDescription == "cancelled" to see if we
        // shouldn't report the fact that the task was cancelled (liklely as a result of
        // checking the response; see above) to the client, as the response-error itself
        // is certain to be more useful

        // TODO: The fact that we have this here is also probably why multiple subscriptions
        // get created after an error occurs - need to check if a resumable subscripiton
        // has already created / is creating a new subscription before creating another
        // new one

        subscription.onError?(error!)
    }

    // MARK: TLS auth challenge insecure

    // TODO: Check all this shit

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
