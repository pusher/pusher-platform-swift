import Foundation

public class PPDownloadDelegate: NSObject, PPRequestTaskDelegate {
    public var task: URLSessionTask?

    // We should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil
    public internal(set) var badResponseError: Error? = nil

    public var logger: PPLogger? = nil

    public var destination: PPDownloadFileDestination? = nil
    public var destinationURL: URL? = nil

    public var onSuccess: ((URL) -> Void)?
    public var onError: ((Error) -> Void)?
    public var progressHandler: ((Int64, Int64) -> Void)? = nil

    public override required init() {}

    deinit {
        // TODO: Does this ever get called?
        self.task?.cancel()
    }

    func handleFinishedDownload(tempURL: URL, response: URLResponse?) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        guard let response = response else {
            self.logger?.log("Download finished downloading to \(tempURL.absoluteString) but no response received", logLevel: .debug)
            return
        }

        self.logger?.log(
            "Task with taskIdentifier \(task.taskIdentifier) finished downloading to \(tempURL.absoluteString) with response: \(response.debugDescription)",
            logLevel: .verbose
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            self.logger?.log("Invalid response received \(response.debugDescription) but download completed and has temporary URL location: \(tempURL.absoluteString)", logLevel: .debug)
            onError?(PPRequestTaskDelegateError.invalidHTTPResponse(response: response))
            return
        }

        guard let destination = destination else {
            self.logger?.log("No download file destination provided so returning temporary URL location: \(tempURL.absoluteString)", logLevel: .verbose)
            onSuccess?(tempURL)
            return
        }

        let result = destination(tempURL, httpResponse)
        let destinationURL = result.destinationURL
        let options = result.options

        self.logger?.log("Moving successful download from \(tempURL.absoluteString) to \(destinationURL.absoluteString)", logLevel: .verbose)

        self.destinationURL = destinationURL

        do {
            if options.contains(.removePreviousFile), FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            if options.contains(.createIntermediateDirectories) {
                let directory = destinationURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            onSuccess?(destinationURL)
        } catch let error {
            self.error = error
            onError?(error)
        }
    }

    // Server errors are not reported through the error parameter here, by default.
    // The only errors received through the error parameter are client-side errors,
    // such as being unable to resolve the hostname or connect to the host.
    internal func handleCompletion(error: Error? = nil) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        self.logger?.log("Task \(task.taskIdentifier) handling completion", logLevel: .verbose)

        // TODO: The request is probably DONE DONE so we can tear it all down? Yeah?

        let err = error ?? self.badResponseError

        guard let errorToReport = err else {
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

    func handleDataWritten(bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let task = self.task else {
            self.logger?.log("Task not set in request delegate", logLevel: .debug)
            return
        }

        self.logger?.log(
            "Task with taskIdentifier \(task.taskIdentifier) wrote \(bytesWritten) bytes, taking the total to \(totalBytesWritten)/\(totalBytesExpectedToWrite) bytes",
            logLevel: .verbose
        )

        self.progressHandler?(totalBytesWritten, totalBytesExpectedToWrite)
    }
}

