import Foundation

public typealias TaskIdentifier = Int

public class PPBaseURLSessionDelegate<RequestTaskDelegate: PPRequestTaskDelegate>: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate, URLSessionDownloadDelegate {
    public var insecure: Bool
    public var requests: [TaskIdentifier: PPRequest<RequestTaskDelegate>] = [:]
    public let lock = NSLock()

    public var logger: PPLogger? = nil {
        willSet {
            self.requests.forEach { arg in
                let (_, req) = arg
                req.delegate.logger = newValue
            }
        }
    }

    public subscript(task: URLSessionTask) -> PPRequest<RequestTaskDelegate>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return requests[task.taskIdentifier]
        }

        set {
            lock.lock()
            defer { lock.unlock() }
            requests[task.taskIdentifier] = newValue
        }
    }

    public init(insecure: Bool) {
        self.insecure = insecure
    }

    public func removeRequestPairedWithTaskId(_ taskId: Int) {
        lock.lock()
        defer { lock.unlock() }
        if let _ = requests.removeValue(forKey: taskId) {
            self.logger?.log(
                "Successfully removed request with taskId: \(taskId)",
                logLevel: .verbose
            )
        } else {
            self.logger?.log(
                "Failed to remove request with taskId: \(taskId)",
                logLevel: .verbose
            )
        }
    }

    // MARK: URLSessionDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            self.logger?.log(
                "URLSession \(session.sessionDescription!) became invalid with error: \(error.localizedDescription)",
                logLevel: .error
            )
        } else {
            self.logger?.log(
                "URLSession \(session.sessionDescription!) became invalid",
                logLevel: .verbose
            )
        }
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.previousFailureCount == 0 else {
            challenge.sender?.cancel(challenge)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        if self.insecure {
            let allowAllCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, allowAllCredential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }


    // MARK: URLSessionTaskDelegate

    // TOOD: Should this be communicated somehow? Only used by the background session(s) by default
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        self.logger?.log("Task with taskIdentifier \(task.taskIdentifier) is waiting for connectivity", logLevel: .verbose)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        fatalError("session:task:didCompleteWithError: has no override in subclass for task \(task.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        fatalError("session:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend: has no override in subclass for task \(task.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }


    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        fatalError("session:dataTask:didReceiveData: has no override in subclass for task \(dataTask.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        fatalError("session:dataTask:didReceiveResponse:completionHandler: has no override in subclass for task \(dataTask.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }


    // MARK: URLSessionDownloadDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        fatalError("session:downloadTask:didFinishDownloadingTo: has no override in subclass for task \(downloadTask.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        fatalError("session:downloadTask:didResumeAtOffset:expectedTotalBytes: has no override in subclass for task \(downloadTask.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        fatalError("session:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite: has no override in subclass for task \(downloadTask.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    }
}
