import XCTest
@testable import PusherPlatform

class HeaderValueTests: XCTestCase {
    
    // MARK: - Tests
    
    func testShouldHaveCorrectValueForApplicationFormURLEncoded() {
        XCTAssertEqual(Header.Value.applicationFormURLEncoded.rawValue, "application/x-www-form-urlencoded")
    }

}
