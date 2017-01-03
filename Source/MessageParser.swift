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
    static internal func parse(data: Data) throws -> [Message] {
        guard let dataString = String(data: data, encoding: .utf8) else {
            throw MessageParseError.failedToConvertDataToString(data)
        }

        let stringMessages = dataString.components(separatedBy: "\n")

        var messages: [Message] = []

        for stringMessage in stringMessages {
            guard stringMessage != "" else {
                continue
            }

            guard let stringMessageData = stringMessage.data(using: .utf8) else {
                throw MessageParseError.failedToConvertStringToData(stringMessage)
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: stringMessageData, options: []) else {
                throw MessageParseError.failedToDeserializeJson(stringMessageData)
            }

            guard let jsonArray = jsonObject as? [Any] else {
                throw MessageParseError.failedToCastJSONObjectToDictionary(jsonObject)
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
            case .keepAlive:
                guard let _ = jsonArray[1] as? String else {
                    throw MessageParseError.invalidKeepAliveData(jsonArray[1])
                }

                messages.append(Message.keepAlive)

            case .event:
                guard let eventId = jsonArray[1] as? String else {
                    throw MessageParseError.invalidEventId(jsonArray[1])
                }

                guard let headers = jsonArray[2] as? [String: String] else {
                    throw MessageParseError.invalidHeaders(jsonArray[2])
                }

                let body = jsonArray[3]

                messages.append(Message.event(eventId: eventId, headers: headers, body: body))

            case .eos:
                guard let statusCode = jsonArray[1] as? Int else {
                    throw MessageParseError.invalidStatusCode(jsonArray[1])
                }

                guard let headers = jsonArray[2] as? [String: String] else {
                    throw MessageParseError.invalidHeaders(jsonArray[2])
                }

                let errorBody = jsonArray[3]

                messages.append(Message.eos(statusCode: statusCode, headers: headers, errorBody: errorBody))
            }
        }

        return messages
    }

}

internal enum MessageParseError: Error {
    case failedToConvertDataToString(Data)
    case failedToDeserializeJson(Data)
    case failedToCastJSONObjectToDictionary(Any)
    case failedToConvertStringToData(String)
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
