import Foundation

public class PPSubscriptionDelegate: NSObject, PPRequestTaskDelegate {
    public internal(set) var data: Data = Data()
    public var task: URLSessionDataTask?

    // A subscription should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil

    public var onOpening: (() -> Void)?
    public var onOpen: (() -> Void)?
    public var onEvent: ((String, [String: String], Any) -> Void)?
    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)?
    public var onError: ((Error) -> Void)?

    internal var heartbeatTimeout: Double = 60.0
    internal var heartbeatTimeoutTimer: Timer? = nil

    internal var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? = nil

    public var logger: PPLogger? = nil

    internal lazy var messageParser: MessageParser = {
        let messageParser = MessageParser(logger: self.logger)
        return messageParser
    }()

    public required init(task: URLSessionDataTask? = nil) {
        self.task = task
    }

    deinit {
        self.logger?.log("Cancelling task: \(String(describing: self.task?.taskIdentifier))", logLevel: .verbose)
        self.heartbeatTimeoutTimer?.invalidate()
        self.task?.cancel()
    }

    internal func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            self.handleCompletion(error: RequestError.invalidHttpResponse(response: response, data: nil))

            // TODO: Should this be cancel?

            completionHandler(.cancel)
            return
        }

        if 200..<300 ~= httpResponse.statusCode {
            self.onOpen?()
        } else {

            // TODO: What do we do if no data is eventually received?

            self.badResponse = httpResponse
        }

        completionHandler(.allow)
    }

    @objc(handleData:)
    internal func handle(_ data: Data) {
        // TODO: Timer stuff below

        guard self.badResponse == nil else {
            let error = RequestError.badResponseStatusCode(response: self.badResponse!)

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                self.handleCompletion(error: error)
                return
            }

            guard let errorDict = jsonObject as? [String: String] else {
                self.handleCompletion(error: error)
                return
            }

            guard let errorShort = errorDict["error"] else {
                self.handleCompletion(error: error)
                return
            }

            let errorDescription = errorDict["error_description"]
            let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

            self.handleCompletion(error: RequestError.badResponseStatusCodeWithMessage(response: self.badResponse!, errorMessage: errorString))

            return
        }


        guard let dataString = String(data: data, encoding: .utf8) else {
            self.logger?.log(
                "Failed to convert received Data to String for task id \(String(describing: self.task?.taskIdentifier))",
                logLevel: .verbose
            )
            return
        }

        let stringMessages = dataString.components(separatedBy: "\n")

        // No newline character in data received so the received data should be stored, ready
        // for the next data to be received
        guard stringMessages.count > 1 else {
            self.data.append(data)
            return
        }

        // TODO: Check that last character of dataString is \n

        let messages = self.messageParser.parse(stringMessages: stringMessages)
        self.handle(messages: messages)

        // If we reached this point we should reset the data to an empty Data
        self.data = Data()
    }

//    @objc(handleCompletionWithError:)
    internal func handleCompletion(error: Error? = nil) {
        self.heartbeatTimeoutTimer?.invalidate()
        self.heartbeatTimeoutTimer = nil

        // TODO: Remove me
        self.logger?.log("In PPSubDel handle(err) for task \(String(describing: self.task?.taskIdentifier))", logLevel: .verbose)

        guard self.error == nil else {
            self.logger?.log(
                "Subscription to has already communicated an error: \(String(describing: self.error?.localizedDescription))",
                logLevel: .debug
            )
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

        self.onError?(error!)
    }

    internal func handle(messages: [Message]) {
        for message in messages {
            switch message {
            case Message.keepAlive:
                self.resetHeartbeatTimeoutTimer()
                break
            case Message.event(let eventId, let headers, let body):
                self.onEvent?(eventId, headers, body)
            case Message.eos(let statusCode, let headers, let info):
                self.onEnd?(statusCode, headers, info)
            }
        }
    }

    @objc fileprivate func endSubscription() {
        self.handleCompletion(error: SubscriptionError.heartbeatTimeoutReached)
    }

    // TODO: Fix multiple heartbeat timers being created in certain circumstances

    fileprivate func resetHeartbeatTimeoutTimer() {
        self.heartbeatTimeoutTimer?.invalidate()
        self.heartbeatTimeoutTimer = nil

        DispatchQueue.main.async {
            self.heartbeatTimeoutTimer = Timer.scheduledTimer(
                timeInterval: self.heartbeatTimeout + 2,  // Give the timeout a small amount of leeway
                target: self,
                selector: #selector(self.endSubscription),
                userInfo: nil,
                repeats: false
            )
        }
    }
}
