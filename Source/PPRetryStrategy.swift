import Foundation

public protocol PPRetryStrategy {
    func shouldRetry(given: Error) -> TimeInterval?
    func requestSucceeded()
}

extension PPRetryStrategy {
    public func requestSucceeded() {}
}
