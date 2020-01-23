import XCTest
@testable import PusherPlatform

class RetryableTokenProviderTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldInitializeTokenProviderWithCorrectValues() {
        let tokenProvider = RetryableTokenProvider(tokenProvider: TestTokenProvider(), retryStrategy: TestRetryStrategy(), logger: DefaultLogger())
        
        XCTAssertTrue(tokenProvider.tokenProvider is TestTokenProvider)
        XCTAssertTrue(tokenProvider.retryStrategy is TestRetryStrategy)
        XCTAssertTrue(tokenProvider.logger is DefaultLogger)
    }
    
    func testShouldInitializeTokenProviderWithDefaultRetryStrategyWhenNoOtherRetryStrategyProvided() {
        let tokenProvider = RetryableTokenProvider(tokenProvider: TestTokenProvider())
        
        XCTAssertTrue(tokenProvider.retryStrategy is PPDefaultRetryStrategy)
    }
    
    func testShouldRetrieveTokenFromNestedTokenProvider() {
        let testToken = TestToken(token: "testToken", expiryDate: .distantFuture)
        let nestedTokenProvider = TestTokenProvider(testToken: testToken)
        
        let retryableTokenProvider = RetryableTokenProvider(tokenProvider: nestedTokenProvider)
        
        let expectation = self.expectation(description: "Token retrieval")
        
        retryableTokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertEqual(token as? TestToken, testToken)
                
            default:
                XCTFail("Failed to retrieve token from the nested token provider.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldReturnCachedNonExpiredToken() {
        let firstTestToken = TestToken(token: "firstTestToken", expiryDate: .distantFuture)
        let nestedTokenProvider = TestTokenProvider(testToken: firstTestToken)
        
        let retryableTokenProvider = RetryableTokenProvider(tokenProvider: nestedTokenProvider)
        
        let firstExpectation = self.expectation(description: "First token retrieval")
        
        retryableTokenProvider.fetchToken { _ in
            firstExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        let secondTestToken = TestToken(token: "secondTestToken", expiryDate: .distantFuture)
        nestedTokenProvider.testToken = secondTestToken
        
        let secondExpectation = self.expectation(description: "Second token retrieval")
        
        retryableTokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertEqual(token as? TestToken, firstTestToken)
                
            default:
                XCTFail("Failed to retrieve token from the nested token provider.")
            }
            
            secondExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldReturnDiscardCachedExpiredTokenAndRetrieveNewTokenFromNestedTokenProvider() {
        let firstTestToken = TestToken(token: "firstTestToken", expiryDate: .distantPast)
        let nestedTokenProvider = TestTokenProvider(testToken: firstTestToken)
        
        let retryableTokenProvider = RetryableTokenProvider(tokenProvider: nestedTokenProvider)
        
        let firstExpectation = self.expectation(description: "First token retrieval")
        
        retryableTokenProvider.fetchToken { _ in
            firstExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        
        let secondTestToken = TestToken(token: "secondTestToken", expiryDate: .distantFuture)
        nestedTokenProvider.testToken = secondTestToken
        
        let secondExpectation = self.expectation(description: "Second token retrieval")
        
        retryableTokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertEqual(token as? TestToken, secondTestToken)
                
            default:
                XCTFail("Failed to retrieve token from the nested token provider.")
            }
            
            secondExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldRetryFailedTokenFetchRequest() {
        let testToken = TestToken(token: "testToken", expiryDate: .distantFuture)
        let nestedTokenProvider = TestTokenProvider()
        
        let retryStrategyExpectation = self.expectation(description: "Retry")
        
        let retryStrategy = TestRetryStrategy(shouldRetry: true)
        retryStrategy.didRetryBlock = {
            nestedTokenProvider.testToken = testToken
            
            retryStrategyExpectation.fulfill()
        }
        
        let retryableTokenProvider = RetryableTokenProvider(tokenProvider: nestedTokenProvider, retryStrategy: retryStrategy)
        
        let tokenRetrievalRxpectation = self.expectation(description: "Token retrieval")
        
        retryableTokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertEqual(token as? TestToken, testToken)
                
            default:
                XCTFail("Failed to retrieve token from the nested token provider.")
            }
            
            tokenRetrievalRxpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testShouldReturnRetryStrategyErrorAfterUnsuccessfulRetries() {
        let nestedTokenProvider = TestTokenProvider()
        
        let retryStrategyExpectation = self.expectation(description: "Retry")
        
        let retryStrategy = TestRetryStrategy(shouldRetry: true)
        retryStrategy.didRetryBlock = {
            if retryStrategy.shouldRetry {
                retryStrategy.shouldRetry = false
            }
            else {
                retryStrategyExpectation.fulfill()
            }
        }
        
        let retryableTokenProvider = RetryableTokenProvider(tokenProvider: nestedTokenProvider, retryStrategy: retryStrategy)
        
        let tokenRetrievalRxpectation = self.expectation(description: "Token retrieval")
        
        retryableTokenProvider.fetchToken { result in
            switch result {
            case let .failure(error: error):
                XCTAssertEqual(error as? TestError, TestError.testRetryStrategyError)
            
            default:
                XCTFail("Unexpectedly retrieved token from the web service.")
            }
            
            tokenRetrievalRxpectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
}

// MARK: - Test token provider

extension RetryableTokenProviderTests {
    
    class TestTokenProvider: TokenProvider {
        
        // MARK: - Properties
        
        var testToken: TestToken?
        
        // MARK: - Initializers
        
        init(testToken: TestToken? = nil) {
            self.testToken = testToken
        }
        
        // MARK: - Internal methods
        
        func fetchToken(completionHandler: @escaping (AuthenticationResult) -> Void) {
            if let testToken = self.testToken {
                completionHandler(.authenticated(token: testToken))
            }
            else {
                let error: TestError = .testTokenProviderError
                completionHandler(.failure(error: error))
            }
        }
        
    }
    
}

// MARK: - Test retry strategy

extension RetryableTokenProviderTests {
    
    class TestRetryStrategy: PPRetryStrategy {
        
        // MARK: - Properties
        
        var shouldRetry: Bool
        var didRetryBlock: (() -> Void)?
        
        // MARK: - Initializers
        
        init(shouldRetry: Bool = false) {
            self.shouldRetry = shouldRetry
        }
        
        // MARK: - Internal methods
        
        func shouldRetry(given: Error) -> PPRetryStrategyResult {
            let result: PPRetryStrategyResult = self.shouldRetry ? .retry(after: 0.1) : .doNotRetry(reason: TestError.testRetryStrategyError)
            
            if let didRetryBlock = self.didRetryBlock {
                didRetryBlock()
            }
            
            return result
        }
        
    }
    
}

// MARK: - Test error

extension RetryableTokenProviderTests {
    
    enum TestError: Error {
        
        case testTokenProviderError
        case testRetryStrategyError
        
    }
    
}

// MARK: - Test token

extension RetryableTokenProviderTests {
    
    struct TestToken: Token, Equatable {
        
        // MARK: - Properties
        
        let token: String
        let expiryDate: Date
        
    }
    
}
