import Foundation

public class PPUploadURLSessionDelegate: PPBaseURLSessionDelegate<PPUploadDelegate> {

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

    public override func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let request = self[task] else {
            self.logger?.log(
                "No request found paired with taskIdentifier \(task.taskIdentifier), which sent some body data",
                logLevel: .debug
            )
            return
        }

        request.delegate.handleBodyDataSent(bytesSent: bytesSent, totalBytesSent: totalBytesSent, totalBytesExpectedToSend: totalBytesExpectedToSend)
    }


    // MARK: URLSessionDataDelegate

    public override func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = self[dataTask] else {
            self.logger?.log(
                "No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received some data",
                logLevel: .debug
            )
            return
        }

        request.delegate.handle(data)
    }
}

