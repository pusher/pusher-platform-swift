import Foundation

public class PPSubscriptionDelegate: NSObject, PPRequestTaskDelegate {
    public internal(set) var data: Data = Data()
    public var task: URLSessionDataTask?

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

    internal var heartbeatTimeout: Double = 60.0
    internal var heartbeatTimeoutTimer: Timer? = nil

    internal var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? = nil

    public var logger: PPLogger? = nil

    internal lazy var messageParser: PPMessageParser = {
        let messageParser = PPMessageParser(logger: self.logger)
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
    internal func handle(_ data: Data) {
        // TODO: Timer stuff below

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
                "Failed to convert received Data to String for task id \(String(describing: self.task?.taskIdentifier))",
                logLevel: .verbose
            )
            return
        }

        let stringMessages = dataString.components(separatedBy: "\n")

        // No newline character in data received so the received data should be stored, ready
        // for the next data to be received
        guard stringMessages.count > 1 else {
            return
        }

        // TODO: Could optimise reading here to get messages as early as possible by
        // parsing a message as soon as we have a valid message in the total data, and
        // then just keep the "remainder" stored, rather than waiting until we have a
        // full set of messages. E.g. we could have a stream of data received such that
        // we received messages in this order: 0.5, 2.25, 0.25, and instead of eventually
        // parsing 3 whole messages (0, 0, 3 - respective to when each bit of data is
        // received), we would parse 0, 2, 1
        guard stringMessages.last == "" else {
            return
        }

        let messages = self.messageParser.parse(stringMessages: stringMessages)
        self.handle(messages: messages)

        // If we reached this point we should reset the data to an empty Data
        self.data = Data()
    }

    internal func handleCompletion(error: Error? = nil) {
        self.heartbeatTimeoutTimer?.invalidate()
        self.heartbeatTimeoutTimer = nil

        let err = error ?? self.badResponseError

        guard let errorToReport = err else {
            // TODO: We probably need to keep track of the fact that the subscription has completed and
            // then potentially communicate any error received as data, if that's possible?
            // Maybe we just need to call onEnd here, and be done with it?
            return
        }

        guard self.error == nil else {
            self.logger?.log(
                "Request has already communicated an error: \(String(describing: self.error!.localizedDescription)). New error: \(String(describing: error))",
                logLevel: .debug
            )
            return
        }

        self.error = errorToReport
        self.onError?(errorToReport)
    }

    internal func handle(messages: [PPMessage]) {
        for message in messages {
            switch message {
            case PPMessage.keepAlive:
                self.resetHeartbeatTimeoutTimer()
                break
            case PPMessage.event(let eventId, let headers, let body):
                self.onEvent?(eventId, headers, body)
            case PPMessage.eos(let statusCode, let headers, let info):
                self.onEnd?(statusCode, headers, info)
            }
        }
    }

    @objc fileprivate func endSubscription() {
        self.handleCompletion(error: PPSubscriptionError.heartbeatTimeoutReached)
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

public enum PPSubscriptionError: Error {
    case heartbeatTimeoutReached
}

extension PPSubscriptionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .heartbeatTimeoutReached:
            return "Heartbeat timeout reached for subscription"
        }
    }
}
