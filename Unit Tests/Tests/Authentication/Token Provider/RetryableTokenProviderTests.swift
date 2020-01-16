import XCTest
@testable import PusherPlatform

class RetryableTokenProviderTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldInitializeTokenProviderWithCorrectValues() {
        let tokenProvider = RetryableTokenProvider(tokenProvider: TestTokenProvider(), retryStrategy: TestRetryStrategy(), logger: PPDefaultLogger())
        
        XCTAssertTrue(tokenProvider.tokenProvider is TestTokenProvider)
        XCTAssertTrue(tokenProvider.retryStrategy is TestRetryStrategy)
        XCTAssertTrue(tokenProvider.logger is PPDefaultLogger)
    }
    
    func testShouldInitializeTokenProviderWithDefaultRetryStrategyWhenNoOtherRetryStrategyProvided() {
        let tokenProvider = RetryableTokenProvider(tokenProvider: TestTokenProvider())
        
        XCTAssertTrue(tokenProvider.retryStrategy is PPDefaultRetryStrategy)
    }
    
}

// MARK: - Test token provider

extension RetryableTokenProviderTests {
    
    class TestTokenProvider: TokenProvider {
        
        // MARK: - Internal methods
        
        func fetchToken(completionHandler: @escaping (AuthenticationResult) -> Void) {
        }
        
    }
    
}

// MARK: - Test retry strategy

extension RetryableTokenProviderTests {
    
    class TestRetryStrategy: PPRetryStrategy {
        
        // MARK: - Internal methods
        
        func shouldRetry(given: Error) -> PPRetryStrategyResult {
            return .doNotRetry(reason: given)
        }
        
    }
    
}
