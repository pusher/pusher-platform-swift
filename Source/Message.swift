//
//  Message.swift
//  ElementsSwift
//
//  Created by Hamilton Chapman on 16/11/2016.
//
//

import Foundation

internal enum Message {
    case keepAlive
    case event(eventId: String, headers: [String: String], body: Any)
    case eos(statusCode: Int, headers: [String: String], errorBody: Any)
}
