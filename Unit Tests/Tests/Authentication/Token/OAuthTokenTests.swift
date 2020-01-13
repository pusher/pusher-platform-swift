import XCTest
@testable import PusherPlatform

class OAuthTokenTests: XCTestCase {
    
    // MARK: - Tests
    
    func testParseValidToken() {
        let jsonData = """
        {
            "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NzkxMDE0NjMsImlhdCI6MTU3ODkyODY2MywiaW5zdGFuY2UiOiI5NzU1MTZmMS1mOWUzLTRlNTUtYTQ0ZC1lNDA3OTIzMmY5NDciLCJpc3MiOiJhcGlfa2V5cy80ZTQyOWNjNS0wM2YzLTQwNzctYmY4ZC04YTcxYWMwYWM2ODgiLCJyZWZyZXNoIjp0cnVlLCJzdWIiOiJib2IifQ.OTeVQ8KkX4ms98bsF6waJqcxAf7yMmCAVqFTX1GCOmc",
            "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NzkxMDE0NjMsImlhdCI6MTU3ODkyODY2MywiaW5zdGFuY2UiOiI5NzU1MTZmMS1mOWUzLTRlNTUtYTQ0ZC1lNDA3OTIzMmY5NDciLCJpc3MiOiJhcGlfa2V5cy80ZTQyOWNjNS0wM2YzLTQwNzctYmY4ZC04YTcxYWMwYWM2ODgiLCJyZWZyZXNoIjp0cnVlLCJzdWIiOiJib2IifQ.OTeVQ8KkX4ms98bsF6waJqcxAf7yMmCAVqFTX1GCOmc",
            "user_id": "bob",
            "token_type": "bearer",
            "expires_in": 86400
        }
        """.jsonData()
        
        XCTAssertNoThrow(try OAuthToken(from: jsonData.jsonDecoder())) { token in
            let now = Date()
            
            XCTAssertEqual(token.token, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE1NzkxMDE0NjMsImlhdCI6MTU3ODkyODY2MywiaW5zdGFuY2UiOiI5NzU1MTZmMS1mOWUzLTRlNTUtYTQ0ZC1lNDA3OTIzMmY5NDciLCJpc3MiOiJhcGlfa2V5cy80ZTQyOWNjNS0wM2YzLTQwNzctYmY4ZC04YTcxYWMwYWM2ODgiLCJyZWZyZXNoIjp0cnVlLCJzdWIiOiJib2IifQ.OTeVQ8KkX4ms98bsF6waJqcxAf7yMmCAVqFTX1GCOmc")
            XCTAssertGreaterThan(token.expiryDate, now)
        }
    }
    
}
