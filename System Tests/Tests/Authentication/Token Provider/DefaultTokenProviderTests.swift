import XCTest
@testable import PusherPlatform

class DefaultTokenProviderTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldRetrieveTokenFromTestTokenSerivce() {
        let url = URL(tokenProviderURLFor: Environment.instanceLocator)
        let userQueryItem = URLQueryItem(name: "user_id", value: "bob")
        
        let tokenProvider = DefaultTokenProvider(url: url, queryItems: [userQueryItem])
        
        let expectation = self.expectation(description: "Token retrieval")
        
        tokenProvider.fetchToken { result in
            switch result {
            case let .authenticated(token):
                XCTAssertTrue(token.value.count > 0)
                XCTAssertFalse(token.isExpired)
                
            default:
                XCTFail("Failed to retrieve token from the web service.")
            }
            
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
}
