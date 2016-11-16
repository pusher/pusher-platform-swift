//
//  MessageParser.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 16/11/2016.
//
//

import Foundation

internal struct MessageParser {
    static fileprivate func parseMessageTypeCode(messageTypeCode: Int) throws -> MessageType {
        switch messageTypeCode {
        case 0: return .KEEP_ALIVE
        case 1: return .EVENT
        case 255: return .EOS
        default: throw MessageParseError.unknownMessageTypeCode(messageTypeCode)
        }
    }

    // Parse errors are truly unexpected here - we trust the server to give us good data
    static internal func parse(data: Data) throws -> Message {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []), let jsonArray = jsonObject as? [Any] else {
            // TODO: Log what was trying to be deserialzied here or in catch block where this is called
            throw MessageParseError.unableToDeserializeJsonResponse
        }

        guard jsonArray.count != 0 else {
            throw MessageParseError.emptyJsonArray
        }

        guard let messageTypeCode = jsonArray[0] as? Int else {
            throw MessageParseError.invalidMessageTypeCode
        }

        let messageType = try parseMessageTypeCode(messageTypeCode: messageTypeCode)

        guard jsonArray.count == messageType.numberOfElements() else {
            throw MessageParseError.jsonArrayWrongLengthForMessageType(messageType, jsonArray.count)
        }

        switch messageType {
        case .KEEP_ALIVE:
            guard let _ = jsonArray[1] as? String else {
                throw MessageParseError.invalidKeepAliveData(jsonArray[1])
            }

            return Message.keepAlive

        case .EVENT:
            guard let eventId = jsonArray[1] as? String else {
                throw MessageParseError.invalidEventId(jsonArray[1])
            }

            guard let headers = jsonArray[2] as? [String: String] else {
                throw MessageParseError.invalidHeaders(jsonArray[2])
            }

            let body = jsonArray[3]

            return Message.event(eventId: eventId, headers: headers, body: body)


        case .EOS:
            guard let statusCode = jsonArray[1] as? Int else {
                throw MessageParseError.invalidStatusCode(jsonArray[1])
            }

            guard let headers = jsonArray[2] as? [String: String] else {
                throw MessageParseError.invalidHeaders(jsonArray[2])
            }

            let errorBody = jsonArray[3]

            return Message.eos(statusCode: statusCode, headers: headers, errorBody: errorBody)
        }
    }

}

internal enum MessageParseError: Error {
    case unableToDeserializeJsonResponse
    case emptyJsonArray
    case jsonArrayWrongLengthForMessageType(MessageType, Int)
    case unknownMessageTypeCode(Int)
    case unknownError
    case invalidMessageTypeCode
    case invalidEventId(Any)
    case invalidHeaders(Any)
    case invalidKeepAliveData(Any)
    case invalidStatusCode(Any)
}

internal enum MessageType {
    case KEEP_ALIVE
    case EVENT
    case EOS

    internal func numberOfElements() -> Int {
        switch self {
        case .KEEP_ALIVE: return 2
        case .EVENT: return 4
        case .EOS: return 4
        }
    }
}
