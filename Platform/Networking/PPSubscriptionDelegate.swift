import Foundation

public class PPSubscriptionDelegate: NSObject, PPRequestTaskDelegate {
    public internal(set) var data: Data = Data()
    public var task: URLSessionTask?

    // A subscription should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil
    public internal(set) var badResponseError: Error? = nil

    public var onOpening: (() -> Void)?
    public var onOpen: (() -> Void)?
    public var onEvent: ((String, [String: String], Any) -> Void)?
    public var onEnd: ((Int?, [String: String]?, Any?) -> Void)?
    public var onError: ((Error) -> Void)?

    // TODO: Check this is being set properly
    var heartbeatTimeout: Double = 60.0
    var heartbeatTimeoutTimer: PPRepeater? = nil

    public var logger: PPLogger? = nil

    lazy var messageParser: PPMessageParser = {
        let messageParser = PPMessageParser(logger: self.logger)
        return messageParser
    }()

    public var requestCleanup: ((Int) -> Void)? = nil

    public override required init() {}

    deinit {
        if let task = self.task {
            self.logger?.log("Cancelling task with ID: \(task.taskIdentifier)", logLevel: .verbose)
        } else {
            self.logger?.log("Cancelling task with unkown ID", logLevel: .verbose)
        }
        self.task?.cancel()
        self.logger?.log("Invalidating heartbeatTimeoutTimer: \(self.heartbeatTimeoutTimer.debugDescription)", logLevel: .verbose)
        self.heartbeatTimeoutTimer = nil
    }

    func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        self.logger?.log("Task \(task.taskIdentifier) handling response: \(response.debugDescription)", logLevel: .verbose)

        guard let httpResponse = response as? HTTPURLResponse else {
            self.handleCompletion(error: PPRequestTaskDelegateError.invalidHTTPResponse(response: response))

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
    func handle(_ data: Data) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        guard self.badResponse == nil else {
            let error = PPRequestTaskDelegateError.badResponseStatusCode(response: self.badResponse!)

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                self.badResponseError = error
                return
            }

            guard let errorDict = jsonObject as? [String: String] else {
                self.badResponseError = error
                return
            }

            guard let errorShort = errorDict["error"] else {
                self.badResponseError = error
                return
            }

            let errorDescription = errorDict["error_description"]
            let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

            self.badResponseError = PPRequestTaskDelegateError.badResponseStatusCodeWithMessage(
                response: self.badResponse!,
                errorMessage: errorString
            )

            return
        }

        // We always append the data here
        self.data.append(data)

        guard let dataString = String(data: self.data, encoding: .utf8) else {
            self.logger?.log(
                "Failed to convert received Data to String for task id \(task.taskIdentifier)",
                logLevel: .verbose
            )
            return
        }

        self.logger?.log("Task \(task.taskIdentifier) handling dataString: \(dataString)", logLevel: .verbose)

        var stringMessages = dataString.components(separatedBy: "\n")

        // No newline character in data received so the received data should be stored, ready
        // for the next data to be received
        guard stringMessages.count > 1 else {
            return
        }

        // We could have a stream of data received such that we received messages
        // in this order: 2.25, 2.25, 0.5, and instead of eventually parsing 5
        // whole messages (0, 0, 5 - respective to when each bit of data is
        // received), we would parse 2, 2, 1

        var incompleteStringMessage: String? = nil

        if stringMessages.last != "" {
            self.logger?.log(
                "Last message not an empty string, which means it will be parsed when the remaining event data is received",
                logLevel: .verbose
            )
            // Remove and store the last message so that it can be parsed in future
            // when the remaining event data is received
            incompleteStringMessage = stringMessages.popLast()
        }

        let messages = self.messageParser.parse(stringMessages: stringMessages)
        self.handle(messages: messages)

        // If we reached this point we should reset the data to an empty Data, or
        // if there was an incomplete message then we convert that back to Data
        // and store that
        self.data = incompleteStringMessage?.data(using: .utf8) ?? Data()
    }

    func handleCompletion(error: Error? = nil) {
        if let task = self.task {
            self.logger?.log("Task \(task.taskIdentifier) handling completion", logLevel: .verbose)
            self.cancelTask()
        } else {
            self.logger?.log("Task with unknown id handling completion", logLevel: .verbose)
        }

        self.cleanUpHeartbeatTimeoutTimer()

        let err = error ?? self.badResponseError

        guard let errorToReport = err else {
            // TODO: We probably need to keep track of the fact that the subscription has completed and
            // then potentially communicate any error received as data, if that's possible?
            // Maybe we just need to call onEnd here, and be done with it?
            return
        }

        guard self.error == nil else {
            if (errorToReport as NSError).code == NSURLErrorCancelled {
                self.logger?.log("Request cancelled; likely due to an explicit call to end it, or a heartbeat timeout", logLevel: .verbose)
            } else {
                self.logger?.log(
                    "Request has already communicated an error: \(self.error!.localizedDescription). New error: \(errorToReport.localizedDescription)",
                    logLevel: .debug
                )
            }

            return
        }

        self.error = errorToReport
        self.onError?(errorToReport)
    }

    func handle(messages: [PPMessage]) {
        for message in messages {
            switch message {
            case PPMessage.keepAlive:
                self.resetHeartbeatTimeoutTimer()
                break
            case PPMessage.event(let eventId, let headers, let body):
                self.onEvent?(eventId, headers, body)
            case PPMessage.eos(let statusCode, let headers, let info):
                self.handleEos(statusCode: statusCode, headers: headers, info: info)
            }
        }
    }

    func handleEos(statusCode: Int, headers: [String: String], info: Any) {
        var error: Error? = nil

        // TODO: Fix this stuff with error being shadowed etc

        guard let errorInfo = info as? [String: String] else {
            let error = PPSubscriptionError.eosWithoutInfo(info)
            self.logger?.log(error.localizedDescription, logLevel: .verbose)

            self.cancelTask()
            self.cleanUpHeartbeatTimeoutTimer()
            self.onEnd?(statusCode, headers, info)
            return
        }

        guard let errorShort = errorInfo["error"] else {
            let error = PPSubscriptionError.eosWithoutErrorInformation(errorInfo: errorInfo)
            self.logger?.log(error.localizedDescription, logLevel: .verbose)

            self.cancelTask()
            self.cleanUpHeartbeatTimeoutTimer()
            self.onEnd?(statusCode, headers, info)
            return
        }

        let errorDescription = errorInfo["error_description"]
        let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

        guard let retryAfterString = headers["retry-after"], let retryAfterTimeInterval = Double(retryAfterString) else {
            let error = PPSubscriptionError.eosWithoutRetryAfter(errorMessage: errorString)
            self.logger?.log(error.localizedDescription, logLevel: .verbose)

            self.cancelTask()
            self.cleanUpHeartbeatTimeoutTimer()
            self.onEnd?(statusCode, headers, info)
            return
        }

        guard error == nil else {
            self.logger?.log(error!.localizedDescription, logLevel: .verbose)

            self.cancelTask()
            self.cleanUpHeartbeatTimeoutTimer()
            self.onEnd?(statusCode, headers, info)
            return
        }

        error = PPSubscriptionError.eosWithRetryAfter(timeInterval: retryAfterTimeInterval, errorMessage: errorString)
        self.logger?.log(error!.localizedDescription, logLevel: .verbose)

        self.handleCompletion(error: error)
    }

    func endSubscription() {
        self.cleanUpHeartbeatTimeoutTimer()

        // TODO: Should all of these be nil?
        self.onEnd?(nil, nil, nil)
    }

    func cleanUpHeartbeatTimeoutTimer() {
        self.heartbeatTimeoutTimer = nil
    }

    func cancelTask() {
        guard let task = self.task else { return }
        self.logger?.log("Cancelling task \(task.taskIdentifier)", logLevel: .verbose)
        task.cancel()
    }

    fileprivate func endSubscriptionAfterHeartbeatTimeout() {
        self.logger?.log("Ending subscription after heartbeat timeout", logLevel: .verbose)
        self.handleCompletion(error: PPSubscriptionError.heartbeatTimeoutReached)
    }

    fileprivate func resetHeartbeatTimeoutTimer() {
        self.logger?.log("Resetting heartbeat timeout timer", logLevel: .verbose)

        self.heartbeatTimeoutTimer = nil

        self.heartbeatTimeoutTimer = PPRepeater.once(
            after: .seconds(heartbeatTimeout + 2) // Give the timeout a small amount of leeway
        ) { [weak self] _ in
            guard let strongSelf = self else {
                print("self is nil when trying to reset a heartbeat timeout timer")
                return
            }

            strongSelf.endSubscriptionAfterHeartbeatTimeout()
        }
    }
}

public enum PPSubscriptionError: Error {
    case heartbeatTimeoutReached
    case eosWithRetryAfter(timeInterval: TimeInterval, errorMessage: String)
    case eosWithoutRetryAfter(errorMessage: String)
    case eosWithoutErrorInformation(errorInfo: [String: String])
    case eosWithoutInfo(Any)
}

extension PPSubscriptionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .heartbeatTimeoutReached:
            return "Heartbeat timeout reached for subscription"
        case .eosWithRetryAfter(let retryAfter, let errorString):
            return "Receievd EOS with instruction to retry subscription after \(retryAfter)s. Error: \(errorString)"
        case .eosWithoutRetryAfter(let errorString):
            return "Receievd EOS without instruction to retry subscription. Error: \(errorString)"
        case .eosWithoutErrorInformation:
            return "Receievd EOS without error information"
        case .eosWithoutInfo(let info):
            return "Failed to cast EOS info object to Dictionary: \(info)"
        }
    }
}
