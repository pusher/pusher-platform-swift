import Foundation

public class PPSubscriptionDelegate: NSObject, URLSessionDataDelegate {
    internal let subscriptionQueue: DispatchQueue
    public internal(set) var data: Data = Data()
    public var task: URLSessionDataTask?

    // TODO: Maybe this could be better named?
    public internal(set) var error: Error? = nil
    public internal(set) var badResponseStatusCodeError: RequestError? = nil

    public var onOpening: (() -> Void)?
    public var onOpen: (() -> Void)?
    public var onEvent: ((String, [String: String], Any) -> Void)?
    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)?
    public var onError: ((Error) -> Void)?

    internal var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? = nil

    public init(task: URLSessionDataTask? = nil) {
        self.subscriptionQueue = DispatchQueue(label: "com.pusherplatform.swift.subscriptiondelegate.\(NSUUID().uuidString)")
        self.task = task

        // TODO: Maybe onXXXX shouldn't be in init and should have to be set after init?

//        onOpening: (() -> Void)? = nil,
//        onOpen: (() -> Void)? = nil,
//        onEvent: ((String, [String: String], Any) -> Void)? = nil,
//        onEnd: ((Int?, [String: String]?, Any?) -> Void)? = nil,
//        onError: ((Error) -> Void)? = nil

//        self.onOpening = onOpening
//        self.onOpen = onOpen
//        self.onEvent = onEvent
//        self.onEnd = onEnd
//        self.onError = onError
    }

    deinit {
        // TODO: Is this legit?
        self.task?.cancel()
    }

    internal func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            self.onError?(RequestError.invalidHttpResponse(response: response, data: nil))

            // TODO: Should this be cancel?

            completionHandler(.cancel)
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            self.onOpen?()
        } else {

            // TODO: What do we do if no data is eventually received?

            self.badResponseStatusCodeError = RequestError.badResponseStatusCode(response: httpResponse, errorMessage: nil)
        }

        completionHandler(.allow)
    }

    @objc(handleData:)
    internal func handle(_ data: Data) {
        print("DELEGATE HANDLING DATA FOR TASK \(String(describing: self.task?.taskIdentifier)) with data: \(String(data: data, encoding: .utf8))")

        // TODO: Timer stuff below

        // TODO: This is designed to capture more context about an error that occurs
        // in conjunction with a unacceptable status code. It needs to be made more
        // robust though.

        guard self.badResponseStatusCodeError == nil else {
            let error = self.badResponseStatusCodeError!

            if case .badResponseStatusCode(response: let response, errorMessage: _) = error {
                guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                    self.handle(error)
                    return
                }

                guard let errorDict = jsonObject as? [String: String] else {
                    self.handle(error)
                    return
                }

                guard let errorShort = errorDict["error"] else {
                    // TODO: Maybe log stuff in here if the error response received is invalid? Probs not
                    self.handle(error)
                    return
                }

                let errorDescription = errorDict["error_description"]
                let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

                self.handle(RequestError.badResponseStatusCode(response: response, errorMessage: errorString))
            }

            return
        }


        // TODO: This still isn't perfect - we need to handle the case where 1.5 messages
        // are received, i.e. one full valid message and then half a one. The half message
        // needs to be stored as the data to be appended to. We also need to account for the 
        // possiblity that an invalid message is received and then a valid one is received.
        // In other words, there may have been a temporary problem, so if appending the newly
        // received data does not lead to a valid message(s) then discard the stored data and
        // continue parsing new messages without the old data being kept around.

        guard let dataString = String(data: data, encoding: .utf8) else {
            DefaultLogger.Logger.log(message: "Failed to convert received Data to String for task id \(String(describing: self.task?.taskIdentifier))")
            return
        }

        let stringMessages = dataString.components(separatedBy: "\n")

//        print("String messages incoming:")
//        debugPrint(stringMessages)

        // No newline character in data received so the received data should be stored, ready
        // for the next data to be received
        guard stringMessages.count > 1 else {
            print("String messages count is not greater than 1: \(stringMessages)")
            self.data.append(data)
            return
        }

        // TODO: Check that last character of dataString is \n

        let messages = MessageParser.parse(stringMessages: stringMessages)
        self.handle(messages: messages)

        // If we reached this point we should reset the data to an empty Data
        self.data = Data()
    }

    @objc(handleError:)
    internal func handle(_ error: Error?) {
        print("In PPSubDel handle(error) for task \(self.task?.taskIdentifier)")

        // TODO: Where do we check if an error has already been communicated? How do we
        // determine whether an error is one that should be communicated immediately or
        // if it should be one that is held until some extra data is received to augment
        // the error returned to the client

        guard self.error == nil else {
            DefaultLogger.Logger.log(message: "Subscription to has already communicated an error: \(String(describing: self.error?.localizedDescription))")
            return
        }

        guard error != nil else {
            let errorToStore = SubscriptionError.unexpectedError
            self.error = errorToStore
            self.onError?(errorToStore)
            return
        }

        self.error = error

        // TOOD: Maybe check if error!.localizedDescription == "cancelled" to see if we
        // shouldn't report the fact that the task was cancelled (liklely as a result of
        // checking the response; see above) to the client, as the response-error itself
        // is certain to be more useful

        // TODO: The fact that we have this here is also probably why multiple subscriptions
        // get created after an error occurs - need to check if a resumable subscripiton
        // has already created / is creating a new subscription before creating another
        // new one

        self.onError?(error!)
    }

    internal func handle(messages: [Message]) {
        for message in messages {
            switch message {
            case Message.keepAlive:
                break
            case Message.event(let eventId, let headers, let body):
                self.onEvent?(eventId, headers, body)
            case Message.eos(let statusCode, let headers, let info):
                self.onEnd?(statusCode, headers, info)
            }
        }
    }
}
