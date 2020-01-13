import XCTest
@testable import PusherPlatform

class TokenTests: XCTestCase {
    
    // MARK: - Types
    
    struct TestToken: Token {
        
        // MARK: - Properties
        
        let token: String
        let expiryDate: Date
        
    }
    
    // MARK: - Tests
    
    func testCorrectlyValidateNonExpiredToken() {
        let token = TestToken(token: "token", expiryDate: Date.distantFuture)
        
        XCTAssertFalse(token.isExpired)
    }
    
    func testCorrectlyValidateExpiredToken() {
        let token = TestToken(token: "token", expiryDate: Date.distantPast)
        
        XCTAssertTrue(token.isExpired)
    }
    
}
