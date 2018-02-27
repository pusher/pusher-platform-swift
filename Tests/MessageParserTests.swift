import XCTest
@testable import PusherPlatform

class MessageParserTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func testParsingAKeepAliveMessage() {
        let messageParser = PPMessageParser(logger: nil)
        let keepAliveString = "[0, \"xxxxxxxxxxxxxxxxxxxxxxxxxxxx\"]\n"
        let messages = messageParser.parse(stringMessages: keepAliveString.components(separatedBy: "\n"))

        XCTAssertEqual(messages, [PPMessage.keepAlive])
    }

    func testParsingAnEOSMessage() {
        let messageParser = PPMessageParser(logger: nil)
        let eosString = "[255, 500, {}, {\"error_description\": \"Internal server error\" }]\n"
        let expectedEOSMessage = PPMessage.eos(
            statusCode: 500,
            headers: [:],
            errorBody: ["error_description": "Internal server error"]
        )
        let messages = messageParser.parse(stringMessages: eosString.components(separatedBy: "\n"))

        XCTAssertEqual(messages, [expectedEOSMessage])
    }

    func testParsingAnEventMessage() {
        let messageParser = PPMessageParser(logger: nil)
        let eventString = "[1, \"123\", {}, {\"data\": [1,2,3]}]\n"
        let expectedEventMessage = PPMessage.event(
            eventId: "123",
            headers: [:],
            body: ["data": [1, 2, 3]]
        )
        let messages = messageParser.parse(stringMessages: eventString.components(separatedBy: "\n"))

        XCTAssertEqual(messages, [expectedEventMessage])
    }

    func testParsingMultipleEventMessages() {
        let messageParser = PPMessageParser(logger: nil)
        let eventsString = "[1, \"123\", {}, {\"data\": [1,2,3]}]\n[1, \"124\", {}, {\"data\": [4,5,6]}]\n"
        let expectedEventMessages = [
            PPMessage.event(
                eventId: "123",
                headers: [:],
                body: ["data": [1, 2, 3]]
            ),
            PPMessage.event(
                eventId: "124",
                headers: [:],
                body: ["data": [4, 5, 6]]
            )
        ]
        let messages = messageParser.parse(stringMessages: eventsString.components(separatedBy: "\n"))

        XCTAssertEqual(messages, expectedEventMessages)
    }

    func testParsingMultipleEventMessagesWhereNotAllAreComplete() {
        let messageParser = PPMessageParser(logger: nil)
        let eventsString = "[1, \"123\", {}, {\"data\": [1,2,3]}]\n[1, \"124\", {}, {\"data\": [4,5,6]}]\n[1, \"125\", {"
        let expectedEventMessages = [
            PPMessage.event(
                eventId: "123",
                headers: [:],
                body: ["data": [1, 2, 3]]
            ),
            PPMessage.event(
                eventId: "124",
                headers: [:],
                body: ["data": [4, 5, 6]]
            )
        ]
        let messages = messageParser.parse(stringMessages: eventsString.components(separatedBy: "\n"))

        XCTAssertEqual(messages, expectedEventMessages)
    }

    func testParsingInvalidEventMessage() {
        let messageParser = PPMessageParser(logger: nil)
        let eventString = "[1, \"123\", 7, {\"data\": [1,2,3]}]\n"
        let messages = messageParser.parse(stringMessages: eventString.components(separatedBy: "\n"))

        XCTAssertEqual(messages, [])
    }
}


extension PPMessage: Equatable {
    static public func ==(lhs: PPMessage, rhs: PPMessage) -> Bool {
        switch (lhs, rhs) {
        case (.keepAlive, .keepAlive):
            return true
        case (let .event(id, headers, body), let .event(id2, headers2, body2)):
            guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []),
                let bodyData2 = try? JSONSerialization.data(withJSONObject: body2, options: []) else {
                    return false
            }
            return id == id2 && headers == headers2 && bodyData == bodyData2
        case (let .eos(status, headers, errorBody), let .eos(status2, headers2, errorBody2)):
            guard let errorBodyData = try? JSONSerialization.data(withJSONObject: errorBody, options: []),
                let errorBodyData2 = try? JSONSerialization.data(withJSONObject: errorBody2, options: []) else {
                    return false
            }
            return status == status2 && headers == headers2 && errorBodyData == errorBodyData2
        default:
            return false
        }
    }
}
