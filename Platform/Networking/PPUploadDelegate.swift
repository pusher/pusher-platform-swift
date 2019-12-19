import Foundation

public class PPUploadDelegate: NSObject, PPRequestTaskDelegate {
    public internal(set) var data: Data = Data()
    public var task: URLSessionTask?

    // We should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil
    public internal(set) var badResponseError: Error? = nil

    public var logger: PPLogger? = nil

    public var onSuccess: ((Data) -> Void)?
    public var onError: ((Error) -> Void)?
    public var progressHandler: ((Int64, Int64) -> Void)? = nil

    public override required init() {}

    deinit {
        // TODO: Does this ever get called?
        self.task?.cancel()
    }

    func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        self.logger?.log("Task \(task.taskIdentifier) handling response: \(response.debugDescription)", logLevel: .verbose)

        guard let httpResponse = response as? HTTPURLResponse else {
            self.handleCompletion(error: PPRequestTaskDelegateError.invalidHTTPResponse(response: response))
            completionHandler(.cancel)
            return
        }

        if !(200..<300).contains(httpResponse.statusCode) {
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

        if let dataString = String(data: data, encoding: .utf8) {
            self.logger?.log("Task \(task.taskIdentifier) handling dataString: \(dataString)", logLevel: .verbose)
        } else {
            self.logger?.log("Task \(task.taskIdentifier) handling data", logLevel: .verbose)
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

        self.data.append(data)
    }

    // Server errors are not reported through the error parameter here, by default.
    // The only errors received through the error parameter are client-side errors,
    // such as being unable to resolve the hostname or connect to the host.
    func handleCompletion(error: Error? = nil) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        self.logger?.log("Task \(task.taskIdentifier) handling completion", logLevel: .verbose)


        // TODO: The request is probably DONE DONE so we can tear it all down? Yeah?

        let err = error ?? self.badResponseError

        guard let errorToReport = err else {
            self.onSuccess?(self.data)
            return
        }

        guard self.error == nil else {
            if (errorToReport as NSError).code == NSURLErrorCancelled {
                self.logger?.log("Request cancelled", logLevel: .verbose)
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

    func handleBodyDataSent(bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        self.logger?.log(
            "Task \(task.taskIdentifier) sent \(bytesSent) bytes, taking the total to \(totalBytesSent)/\(totalBytesExpectedToSend) bytes",
            logLevel: .verbose
        )

        self.progressHandler?(totalBytesSent, totalBytesExpectedToSend)
    }
}
