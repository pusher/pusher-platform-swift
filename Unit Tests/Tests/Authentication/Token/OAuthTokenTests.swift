import XCTest
@testable import PusherPlatform

class OAuthTokenTests: XCTestCase {
    
    // MARK: - Tests
    
    func testParseValidToken() {
        guard let url = Bundle.current.url(forResource: "token", withExtension: "json"),
            let jsonData = try? Data(contentsOf: url) else {
                fatalError("Failed to read token fixture.")
        }
        
        XCTAssertNoThrow(try OAuthToken(from: jsonData.jsonDecoder())) { token in
            XCTAssertEqual(token.token, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1Nzk2MDQxNDcsImlhdCI6MTU3OTUxNzc0NywiaW5zdGFuY2UiOiI5NzU1MTZmMS1mOWUzLTRlNTUtYTQ0ZC1lNDA3OTIzMmY5NDciLCJpc3MiOiJhcGlfa2V5cy80ZTQyOWNjNS0wM2YzLTQwNzctYmY4ZC04YTcxYWMwYWM2ODgiLCJzdWIiOiJib2IifQ.5uyq_dBsGfdyqnDVDhm7d0R9w6HGApllBLVhwYHCNBI")
            XCTAssertEqual(token.expiryDate.timeIntervalSinceNow, 86400, accuracy: 0.001)
        }
    }
    
}
