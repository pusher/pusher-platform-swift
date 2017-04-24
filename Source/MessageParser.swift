import Foundation

internal struct MessageParser {
    static fileprivate func parseMessageTypeCode(messageTypeCode: Int) throws -> MessageType {
        switch messageTypeCode {
        case 0: return .keepAlive
        case 1: return .event
        case 255: return .eos
        default: throw MessageParseError.unknownMessageTypeCode(messageTypeCode)
        }
    }

    // Parse errors are truly unexpected here - we trust the server to give us good data
    static internal func parse(stringMessages: [String]) throws -> [Message] {
        return try stringMessages.flatMap { stringMessage -> Message? in
            guard stringMessage != "" else {
                return nil
            }

            guard let stringMessageData = stringMessage.data(using: .utf8) else {
                throw MessageParseError.failedToConvertStringToData(stringMessage)
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: stringMessageData, options: []) else {
                throw MessageParseError.failedToDeserializeJSON(stringMessage)
            }

            guard let jsonArray = jsonObject as? [Any] else {
                throw MessageParseError.failedToCastJSONObjectToDictionary(jsonObject)
            }

            guard jsonArray.count != 0 else {
                throw MessageParseError.emptyJSONArray
            }

            guard let messageTypeCode = jsonArray[0] as? Int else {
                throw MessageParseError.invalidMessageTypeCode(jsonArray[0])
            }

            let messageType = try parseMessageTypeCode(messageTypeCode: messageTypeCode)

            guard jsonArray.count == messageType.numberOfElements() else {
                throw MessageParseError.jsonArrayWrongLengthForMessageType(messageType, jsonArray.count)
            }

            switch messageType {
            case .keepAlive:
                guard let _ = jsonArray[1] as? String else {
                    throw MessageParseError.invalidKeepAliveData(jsonArray[1])
                }

                return Message.keepAlive

            case .event:
                guard let eventId = jsonArray[1] as? String else {
                    throw MessageParseError.invalidEventId(jsonArray[1])
                }

                guard let headers = jsonArray[2] as? [String: String] else {
                    throw MessageParseError.invalidHeaders(jsonArray[2])
                }

                let body = jsonArray[3]

                return Message.event(eventId: eventId, headers: headers, body: body)

            case .eos:
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

}

internal enum MessageParseError: Error {
    case failedToDeserializeJSON(String)
    case failedToCastJSONObjectToDictionary(Any)
    case failedToConvertStringToData(String)
    case emptyJSONArray
    case jsonArrayWrongLengthForMessageType(MessageType, Int)
    case unknownMessageTypeCode(Int)
    case invalidMessageTypeCode(Any)
    case invalidEventId(Any)
    case invalidHeaders(Any)
    case invalidKeepAliveData(Any)
    case invalidStatusCode(Any)
}

extension MessageParseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToDeserializeJSON(let stringMessage):
            return "Failed to deserialize received string to JSON object: \(stringMessage)"
        case .failedToCastJSONObjectToDictionary(let jsonObject):
            return "Failed to cast JSON object to Dictionary: \(jsonObject)"
        case .failedToConvertStringToData(let stringMessage):
            return "Failed to convert message String to Data: \(stringMessage)"
        case .emptyJSONArray:
            return "Empty JSON array received"
        case .jsonArrayWrongLengthForMessageType(let messageType, let countOfElements):
            return "Expected \(messageType.numberOfElements()) elements in message of type \(messageType.rawValue) but received \(countOfElements)"
        case .unknownMessageTypeCode(let messageTypeCode):
            return "Unknown message type code received: \(messageTypeCode)"
        case .invalidMessageTypeCode(let messageTypeCode):
            return "Received invalid message type code: \(messageTypeCode)"
        case .invalidEventId(let eventId):
            return "Received invalid event ID: \(eventId)"
        case .invalidHeaders(let headers):
            return "Received invalid headers: \(headers)"
        case .invalidKeepAliveData(let keepAliveData):
            return "Received invalid keep-alive data: \(keepAliveData)"
        case .invalidStatusCode(let statusCode):
            return "Received invalid status code: \(statusCode)"
        }
    }
}

internal enum MessageType: String {
    case keepAlive
    case event
    case eos

    internal func numberOfElements() -> Int {
        switch self {
        case .keepAlive: return 2
        case .event: return 4
        case .eos: return 4
        }
    }
}
