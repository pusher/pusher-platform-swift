import Foundation

public class PPRetryStrategy {

    public var maxNumberOfAttempts: Int?
    public var maxTimeIntervalBetweenAttempts: TimeInterval?

    public internal(set) var numberOfAttempts: Int = 0

    public init(maxNumberOfAttempts: Int = 6, maxTimeIntervalBetweenAttempts: TimeInterval? = nil) {
        self.maxNumberOfAttempts = maxNumberOfAttempts
        self.maxTimeIntervalBetweenAttempts = maxTimeIntervalBetweenAttempts
    }

    // TODO: Check all of the [unowned self] capture lists

    public func retry<T>(completionHandler: @escaping (Result<T>) -> Void) {
        let retryAwareCompletionHandler = { [unowned self] (result: Result<T>) in
            switch result {
            case .success(let value):
                self.numberOfAttempts = 0
                completionHandler(.success(value))
            case .failure(let err):
                self.numberOfAttempts += 1

                guard self.maxNumberOfAttempts != nil && self.numberOfAttempts < self.maxNumberOfAttempts! else {
                    DefaultLogger.Logger.log(message: "Maximum number of auth attempts (\(self.maxNumberOfAttempts!)) made by HTTPEndpointAuthorizer. Latest error: \(err)")
                    completionHandler(.failure(err))
                    return
                }

                let timeIntervalBeforeNextAttempt = TimeInterval(self.numberOfAttempts * self.numberOfAttempts)

                let timeBeforeNextAttempt = self.maxTimeIntervalBetweenAttempts != nil
                                          ? min(timeIntervalBeforeNextAttempt, self.maxTimeIntervalBetweenAttempts!)
                                          : timeIntervalBeforeNextAttempt

                if self.maxNumberOfAttempts != nil {
                    DefaultLogger.Logger.log(message: "HTTPEndpointAuthorizer error occurred. Making attempt \(self.numberOfAttempts + 1) of \(self.maxNumberOfAttempts!) in \(timeBeforeNextAttempt)s. Error was: \(err)")
                } else {
                    DefaultLogger.Logger.log(message: "HTTPEndpointAuthorizer error occurred. Making attempt \(self.numberOfAttempts + 1) in \(timeBeforeNextAttempt)s. Error was: \(err)")
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + timeBeforeNextAttempt, execute: { [unowned self] in
                    // retry operation that takes completion handler so something like:

                    // self.retry(completionHandler: completionHandler)
                })
            }
        }

        // Do some shit with the retryAwareCompletionHandler: this is probably just another closure that
        // needs to be accepted as a param

//        functionThatActuallyDoesStuff(completionHandler: retryAwareCompletionHandler)
    }

}
