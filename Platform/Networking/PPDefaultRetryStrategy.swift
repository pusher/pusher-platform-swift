import Foundation

public class PPDefaultRetryStrategy: PPRetryStrategy {

    public var maxNumberOfAttempts: Int?
    public var maxTimeIntervalBetweenAttempts: TimeInterval?

    public internal(set) var numberOfAttempts: Int = 0

    public var logger: PPLogger? = nil

    public init(maxNumberOfAttempts: Int = 6, maxTimeIntervalBetweenAttempts: TimeInterval? = nil) {
        self.maxNumberOfAttempts = maxNumberOfAttempts
        self.maxTimeIntervalBetweenAttempts = maxTimeIntervalBetweenAttempts
    }

    public func requestSucceeded() {
        self.numberOfAttempts = 0
    }

    public func shouldRetry(given error: Error) -> PPRetryStrategyResult {
        self.numberOfAttempts += 1

        if let statusError = error as? PPRequestTaskDelegateError {
            var resWithMessage: (response: HTTPURLResponse, message: String?)? = nil

            switch statusError {
            case .badResponseStatusCode(let res):
                resWithMessage = (response: res, message: nil)
            case .badResponseStatusCodeWithMessage(let res, let msg):
                resWithMessage = (response: res, message: msg)
            default:
                break
            }

            if let resWithMessage = resWithMessage {
                let err = PPDefaultRetryStrategyError.statusCode4XXReceived(
                    response: resWithMessage.response,
                    message: resWithMessage.message
                )
                if 400..<500 ~= resWithMessage.response.statusCode {
                    self.logger?.log(err.localizedDescription, logLevel: .debug)
                    return PPRetryStrategyResult.doNotRetry(reason: err)
                }
            }
        }

        if let maxNumAttempts = self.maxNumberOfAttempts, self.numberOfAttempts >= maxNumAttempts {
            let err = PPDefaultRetryStrategyError.maximumNumberOfAttemptsMade(
                attemptsMade: self.numberOfAttempts,
                latestErrorReceived: error
            )
            self.logger?.log(err.localizedDescription, logLevel: .debug)
            return PPRetryStrategyResult.doNotRetry(reason: err)
        }

        let timeIntervalBeforeNextAttempt = TimeInterval(self.numberOfAttempts * self.numberOfAttempts)

        let timeBeforeNextAttempt = self.maxTimeIntervalBetweenAttempts != nil
                                  ? min(timeIntervalBeforeNextAttempt, self.maxTimeIntervalBetweenAttempts!)
                                  : timeIntervalBeforeNextAttempt

        if let maxAttempts = self.maxNumberOfAttempts {
            self.logger?.log(
                "Making attempt \(self.numberOfAttempts + 1) of \(maxAttempts) in \(timeBeforeNextAttempt)s. Error was: \(error.localizedDescription)",
                logLevel: .debug
            )
        } else {
            self.logger?.log(
                "Making attempt \(self.numberOfAttempts + 1) in \(timeBeforeNextAttempt)s. Error was: \(error.localizedDescription)",
                logLevel: .debug
            )
        }

        return PPRetryStrategyResult.retry(after: timeBeforeNextAttempt)
    }

}

public enum PPDefaultRetryStrategyError: Error {
    case maximumNumberOfAttemptsMade(attemptsMade: Int, latestErrorReceived: Error)
    case statusCode4XXReceived(response: HTTPURLResponse, message: String?)
}

extension PPDefaultRetryStrategyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .maximumNumberOfAttemptsMade(let attemptsMade, let latestErrorReceived):
            return "Maximum number of attempts (\(attemptsMade)) made. Last error receieved was: \(latestErrorReceived.localizedDescription)"
        case .statusCode4XXReceived(let response, let message):
            let errMessage = message ?? ""
            return "Response received with status code \(response.statusCode). Error message: \(errMessage). Response: \(response.description)"
        }
    }
}
