import Foundation

public class PPGeneralRequestDelegate: NSObject, PPRequestTaskDelegate {
    public internal(set) var data: Data = Data()
    public var task: URLSessionDataTask?

    // A subscription should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil

    public var onSuccess: ((Data) -> Void)?
    public var onError: ((Error) -> Void)?

    internal var waitForDataAccompanyingBadStatusCodeResponseTimer: Timer? = nil

    public required init(task: URLSessionDataTask? = nil) {
        self.task = task
    }

    deinit {
        // TODO: Remove me - although it doesn't seem to currently be called (see notes in notebook)

        DefaultLogger.Logger.log(message: "About to cancel task: \(String(describing: self.task?.taskIdentifier))")

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
//            self.onOpen?()
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

        print("APPENDING DATA")

        self.data.append(data)
    }

    @objc(handleError:)
    internal func handleCompletion(error: Error? = nil) {

        // TODO: Remove me

        DefaultLogger.Logger.log(message: "In PPGenReqDel handle(err) for task \(String(describing: self.task?.taskIdentifier))")

        guard self.error == nil else {
            DefaultLogger.Logger.log(message: "Request to has already communicated an error: \(String(describing: self.error?.localizedDescription))")
            return
        }

        // TODO: The request is probably DONE DONE so we can tear it all down? Yeah?

        guard let error = error  else {
//            let errorToStore = SubscriptionError.unexpectedError
//            self.error = errorToStore
//            self.onError?(errorToStore)

            self.onSuccess?(self.data)
            return
        }

        self.error = error

        self.onError?(error)
    }

}
