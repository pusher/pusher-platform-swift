import Foundation

internal struct MessageParser {
    static fileprivate func parseMessageTypeCode(messageTypeCode: Int) -> MessageType? {
        switch messageTypeCode {
        case 0: return .keepAlive
        case 1: return .event
        case 255: return .eos
        default: return nil
        }
    }

    // Parse errors are truly unexpected here - we trust the server to give us good data
    static internal func parse(stringMessages: [String]) -> [Message] {
        return stringMessages.flatMap { stringMessage -> Message? in
            guard stringMessage != "" else {
                return nil
            }

            guard let stringMessageData = stringMessage.data(using: .utf8) else {
                DefaultLogger.Logger.log(message: "Failed to convert message String to Data: \(stringMessage)")
                return nil
            }

            guard let jsonObject = try? JSONSerialization.jsonObject(with: stringMessageData, options: []) else {
                DefaultLogger.Logger.log(message: "Failed to deserialize received string to JSON object: \(stringMessage)")
                return nil
            }

            guard let jsonArray = jsonObject as? [Any] else {
                DefaultLogger.Logger.log(message: "Failed to cast JSON object to Dictionary: \(jsonObject)")
                return nil
            }

            guard jsonArray.count != 0 else {
                DefaultLogger.Logger.log(message: "Empty JSON array received")
                return nil
            }

            guard let messageTypeCode = jsonArray[0] as? Int else {
                DefaultLogger.Logger.log(message: "Received invalid message type code: \(jsonArray[0])")
                return nil
            }

            guard let messageType = parseMessageTypeCode(messageTypeCode: messageTypeCode) else {
                DefaultLogger.Logger.log(message: "Unknown message type code received: \(messageTypeCode)")
                return nil
            }

            guard jsonArray.count == messageType.numberOfElements() else {
                DefaultLogger.Logger.log(message: "Expected \(messageType.numberOfElements()) elements in )message of type \(messageType.rawValue) but received \(jsonArray.count)")
                return nil
            }

            switch messageType {
            case .keepAlive:
                guard let _ = jsonArray[1] as? String else {
                    DefaultLogger.Logger.log(message: "Received invalid keep-alive data: \(jsonArray[1])")
                    return nil
                }

                print("Keep alive received at \(Date().timeIntervalSince1970)")

                return Message.keepAlive

            case .event:
                guard let eventId = jsonArray[1] as? String else {
                    DefaultLogger.Logger.log(message: "Received invalid event ID: \(jsonArray[1])")
                    return nil
                }

                guard let headers = jsonArray[2] as? [String: String] else {
                    DefaultLogger.Logger.log(message: "Received invalid headers: \(jsonArray[2])")
                    return nil
                }

                let body = jsonArray[3]

                return Message.event(eventId: eventId, headers: headers, body: body)

            case .eos:
                guard let statusCode = jsonArray[1] as? Int else {
                    DefaultLogger.Logger.log(message: "Received invalid status code: \(jsonArray[1])")
                    return nil
                }

                guard let headers = jsonArray[2] as? [String: String] else {
                    DefaultLogger.Logger.log(message: "Received invalid headers: \(jsonArray[2])")
                    return nil
                }

                let errorBody = jsonArray[3]

                return Message.eos(statusCode: statusCode, headers: headers, errorBody: errorBody)
            }
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
