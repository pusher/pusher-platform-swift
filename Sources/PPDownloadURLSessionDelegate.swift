import Foundation

public class PPDownloadURLSessionDelegate: PPBaseURLSessionDelegate<PPDownloadDelegate> {

    // MARK: URLSessionTaskDelegate

    public override func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = self[task] else {
            guard let error = error else {
                self.logger?.log(
                    "No request found paired with taskIdentifier \(task.taskIdentifier), which encountered an unknown error",
                    logLevel: .debug
                )
                return
            }

            if (error as NSError).code == NSURLErrorCancelled {
                self.logger?.log(
                    "No request found paried with taskIdentifier \(task.taskIdentifier) as request was cancelled; likely due to an explicit call to end it, or a heartbeat timeout",
                    logLevel: .debug
                )
            } else {
                self.logger?.log(
                    "No request found paired with taskIdentifier \(task.taskIdentifier), which encountered error: \(error.localizedDescription))",
                    logLevel: .debug
                )
            }

            return
        }

        request.delegate.handleCompletion(error: error)
    }

    // MARK: URLSessionDownloadDelegate

    public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let request = self[downloadTask] else {
            self.logger?.log(
                "No request found paired with taskIdentifier \(downloadTask.taskIdentifier), which finished downloading to \(location.absoluteString)",
                logLevel: .debug
            )
            return
        }

        request.delegate.handleFinishedDownload(tempURL: location, response: downloadTask.response)
    }

    public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let request = self[downloadTask] else {
            self.logger?.log(
                "No request found paired with taskIdentifier \(downloadTask.taskIdentifier), which wrote some data",
                logLevel: .debug
            )
            return
        }

        request.delegate.handleDataWritten(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        self.logger?.log(
            "Task with taskIdentifier \(downloadTask.taskIdentifier) resumed at offset \(fileOffset) and the expected total is \(expectedTotalBytes) bytes",
            logLevel: .verbose
        )

        // TODO: Use this properly when resuming is supported
    }

}
