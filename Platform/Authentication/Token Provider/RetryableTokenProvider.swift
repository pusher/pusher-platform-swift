import Foundation

class RetryableTokenProvider: TokenProvider {
    
    // MARK: - Properties
    
    let tokenProvider: TokenProvider
    let retryStrategy: PPRetryStrategy
    
    let logger: Logger?
    
    private var token: Token?
    private var queue: DispatchQueue
    
    // MARK: - Initializers
    
    init(tokenProvider: TokenProvider, retryStrategy: PPRetryStrategy = PPDefaultRetryStrategy(), logger: Logger? = nil) {
        self.tokenProvider = tokenProvider
        self.retryStrategy = retryStrategy
        self.logger = logger
        self.queue = DispatchQueue(for: RetryableTokenProvider.self)
    }
    
    // MARK: - Token retrieval
    
    func fetchToken(completionHandler: @escaping (AuthenticationResult) -> Void) {
        if let token = self.token, !token.isExpired {
            self.logger?.log("\(String(describing: self)) will return cached token.", logLevel: .verbose)
            self.reportAuthenticationResult(.authenticated(token: token), using: completionHandler)
        }
        else {
            self.queue.async {
                self.scheduleTokenRetrieval(completionHandler: completionHandler)
            }
        }
    }
    
    // MARK: - Private methods
    
    private func scheduleTokenRetrieval(completionHandler: @escaping (AuthenticationResult) -> Void) {
        self.logger?.log("\(String(describing: self)) will try to fetch a new token.", logLevel: .verbose)
        self.tokenProvider.fetchToken { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case let .authenticated(token: token):
                self.token = token
                self.retryStrategy.requestSucceeded()
                self.logger?.log("\(String(describing: self)) received a new token.", logLevel: .verbose)
                self.reportAuthenticationResult(.authenticated(token: token), using: completionHandler)
                
            case let .failure(error: error):
                let shouldRetry = self.retryStrategy.shouldRetry(given: error)
                
                switch shouldRetry {
                case let .retry(after: timeInterval):
                    self.logger?.log("\(String(describing: self)) failed to fetch a new token. Scheduled a retry in \(timeInterval)s.", logLevel: .warning)
                    self.queue.asyncAfter(deadline: .now() + timeInterval) {
                        self.scheduleTokenRetrieval(completionHandler: completionHandler)
                    }
                    
                case let .doNotRetry(reason: retryError):
                    self.logger?.log("\(String(describing: self)) failed to retrieve a new token with error: \(error.localizedDescription)", logLevel: .error)
                    self.reportAuthenticationResult(.failure(error: retryError), using: completionHandler)
                }
                
            }
        }
    }
    
    private func reportAuthenticationResult(_ authenticationResult: AuthenticationResult, using completionHandler: @escaping (AuthenticationResult) -> Void) {
        DispatchQueue.main.async {
            completionHandler(authenticationResult)
        }
    }
    
}
