import Foundation

public class PPSubscriptionDelegate: NSObject, URLSessionDataDelegate {
    internal let subscriptionQueue: DispatchQueue
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

    internal var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? = nil

    public init(task: URLSessionDataTask? = nil) {
        self.subscriptionQueue = DispatchQueue(label: "com.pusherplatform.swift.subscriptiondelegate.\(NSUUID().uuidString)")
        self.task = task
    }

    deinit {
        // TODO: Remove me

        DefaultLogger.Logger.log(message: "About to cancel task: \(String(describing: self.task?.taskIdentifier))")

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
                self.handle(error)
                return
            }

            guard let errorDict = jsonObject as? [String: String] else {
                self.handle(error)
                return
            }

            guard let errorShort = errorDict["error"] else {
                self.handle(error)
                return
            }

            let errorDescription = errorDict["error_description"]
            let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

            self.handle(RequestError.badResponseStatusCodeWithMessage(response: self.badResponse!, errorMessage: errorString))

            return
        }


        guard let dataString = String(data: data, encoding: .utf8) else {
            DefaultLogger.Logger.log(message: "Failed to convert received Data to String for task id \(String(describing: self.task?.taskIdentifier))")
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

        let messages = MessageParser.parse(stringMessages: stringMessages)
        self.handle(messages: messages)

        // If we reached this point we should reset the data to an empty Data
        self.data = Data()
    }

    @objc(handleError:)
    internal func handle(_ error: Error?) {

        // TODO: Remove me

        DefaultLogger.Logger.log(message: "In PPSubDel handle(error) for task \(String(describing: self.task?.taskIdentifier))")

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
