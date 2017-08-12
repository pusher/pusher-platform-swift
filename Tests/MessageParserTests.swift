import PusherPlatform
import XCTest

class MessageParserTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testParsingAKeepAliveMessage() {
        let keepAliveString = "[0, \"xxxxxxxxxxxxxxxxxxxxxxxxxxxx\"]\n"
        let keepAliveData = keepAliveString.data(using: .utf8)

        // TODO: @testable or whatever that annotation is is probably what we want here

        XCTAssertTrue(2 == 1 + 1, "maths")
    }

    func testParsingAnEOSMessage() {
        let eosString = "[255, 500, {}, {\"error_description\": \"Internal server error\" }]\n"
        let eosData = eosString.data(using: .utf8)

        XCTAssertTrue(2 == 1 + 1, "maths")
    }

    func testParsingAnEventMessage() {
        let eventString = "[1, \"123\", {}, {\"data\": [1,2,3]}]\n"
        let eventData = eventString.data(using: .utf8)

        XCTAssertTrue(2 == 1 + 1, "maths")
    }

}
