import XCTest
@testable import PusherPlatform

class TokenTests: XCTestCase {
    
    // MARK: - Types
    
    struct TestToken: Token {
        
        // MARK: - Properties
        
        let value: String
        let expiryDate: Date
        
    }
    
    // MARK: - Tests
    
    func testCorrectlyValidateNonExpiredToken() {
        let token = TestToken(value: "token", expiryDate: Date.distantFuture)
        
        XCTAssertFalse(token.isExpired)
    }
    
    func testCorrectlyValidateExpiredToken() {
        let token = TestToken(value: "token", expiryDate: Date.distantPast)
        
        XCTAssertTrue(token.isExpired)
    }
    
}
